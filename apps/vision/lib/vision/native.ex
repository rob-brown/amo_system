defmodule Vision.Native do
  use GenServer

  require Logger

  alias Evision.VideoCapture
  alias Evision.Mat

  # https://github.com/opencv/opencv/blob/91808e64a1bce0cd981db27414b67eb897e7ecc1/modules/videoio/include/opencv2/videoio.hpp#L141
  # Width of the frames in the video stream.
  @cap_prop_frame_width 3
  # Height of the frames in the video stream.
  @cap_prop_frame_height 4
  # Frame rate.
  @cap_prop_fps 5
  @cap_prop_buffersize 38

  @frame_width 640
  @frame_height 480

  @enforce_keys [:capture]
  defstruct [:capture]

  @name __MODULE__

  def capture(save_file) when is_binary(save_file) do
    path = Path.expand(save_file)
    GenServer.cast(@name, {:capture, path})
  end

  def capture_crop(save_file, {left, top}, {right, bottom})
      when is_binary(save_file) do
    path = Path.expand(save_file)
    box = %{top: top, left: left, bottom: bottom, right: right}
    GenServer.cast(@name, {:capture_crop, path, box})
  end

  def visible(image_file, options \\ []) when is_binary(image_file) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    confidence = Keyword.get(options, :confidence, 0.8)
    GenServer.call(@name, {:visible, path, confidence}, timeout)
  end

  def count(image_file, options \\ []) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    confidence = Keyword.get(options, :confidence, 0.89)
    GenServer.call(@name, {:count, path, confidence}, timeout)
  end

  def count_crop(image_file, crop, options \\ []) when is_binary(image_file) and is_map(crop) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    top = Map.get(crop, :top, 0.0)
    left = Map.get(crop, :left, 0.0)
    bottom = Map.get(crop, :bottom, 1.0)
    right = Map.get(crop, :right, 1.0)
    confidence = Keyword.get(options, :confidence, 0.89)
    box = %{top: top, left: left, bottom: bottom, right: right}
    GenServer.call(@name, {:count_crop, path, box, confidence}, timeout)
  end

  def wait_until_found(image_file, duration, options \\ [])
      when is_binary(image_file) and is_number(duration) do
    timeout = Keyword.get(options, :timeout, duration + 5000)
    path = Path.expand(image_file)
    GenServer.call(@name, {:wait_until_found, path, duration, options}, timeout)
  end

  def wait_until_gone(image_file, duration, options \\ [])
      when is_binary(image_file) and is_number(duration) do
    timeout = Keyword.get(options, :timeout, duration + 5000)
    path = Path.expand(image_file)
    GenServer.call(@name, {:wait_until_gone, path, duration, options}, timeout)
  end

  ## GenServer

  def start_link(index \\ 0) do
    GenServer.start_link(__MODULE__, index, name: @name)
  end

  def init(index) do
    capture = VideoCapture.videoCapture(index)

    if VideoCapture.isOpened(capture) do
      VideoCapture.set(capture, @cap_prop_frame_width, @frame_width)
      VideoCapture.set(capture, @cap_prop_frame_height, @frame_height)
      VideoCapture.set(capture, @cap_prop_fps, 30)
      VideoCapture.set(capture, @cap_prop_buffersize, 1)

      {:ok, %__MODULE__{capture: capture}}
    else
      {:stop, :already_open}
    end
  end

  def child_spec(index) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [index]}
    }
  end

  def handle_cast({:capture, path}, state = %__MODULE__{capture: c}) do
    case capture_frame(c) do
      {:ok, img} ->
        Evision.imwrite(path, img)

      {:error, reason} ->
        Logger.error("Failed to capture image: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_cast({:capture_crop, path, box}, state = %__MODULE__{capture: c}) do
    case capture_frame(c) do
      {:ok, img} ->
        Evision.imwrite(path, crop(img, box))

      {:error, reason} ->
        Logger.error("Failed to capture image: #{inspect(reason)}")
    end

    {:noreply, state}
  end

  def handle_call({:visible, path, confidence}, _from, state = %__MODULE__{capture: c}) do
    with {:ok, template} <- read_image(path),
         {:ok, img} <- capture_frame(c),
         {:ok, info} <- find(img, template, confidence) do
      {:reply, {:ok, info}, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:count, path, confidence}, _from, state = %__MODULE__{capture: c}) do
    with {:ok, template} <- read_image(path),
         {:ok, img} <- capture_frame(c),
         {:ok, count} <- count(img, template, confidence) do
      {:reply, {:ok, count}, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:count_crop, path, box, confidence}, _from, state = %__MODULE__{capture: c}) do
    with {:ok, template} <- read_image(path),
         {:ok, img} <- capture_frame(c),
         cropped = crop(img, box),
         {:ok, count} <- count(cropped, template, confidence) do
      {:reply, {:ok, count}, state}
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(
        {:wait_until_found, path, duration, options},
        _from,
        state = %__MODULE__{capture: c}
      ) do
    confidence = Keyword.get(options, :confidence, 0.8)
    interval = Keyword.get(options, :interval, 100)
    deadline = DateTime.utc_now() |> DateTime.add(duration, :millisecond)
    {:ok, template} = read_image(path)
    result = loop_until_found(c, template, deadline, confidence, interval)
    {:reply, result, state}
  end

  def handle_call(
        {:wait_until_gone, path, duration, options},
        _from,
        state = %__MODULE__{capture: c}
      ) do
    confidence = Keyword.get(options, :confidence, 0.8)
    interval = Keyword.get(options, :interval, 100)
    deadline = DateTime.utc_now() |> DateTime.add(duration, :millisecond)
    {:ok, template} = read_image(path)
    result = loop_until_gone(c, template, deadline, confidence, interval)
    {:reply, result, state}
  end

  def handle_info({_port, {:exit_status, 0}}, state) do
    _ = Logger.debug("Vision exited normally")
    {:stop, :normal, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    _ = Logger.error("Vision exited: #{code}")
    {:stop, code, state}
  end

  def terminate(reason, _state) do
    _ = Logger.warning("Vision terminating because #{inspect(reason)}")
  end

  ## Helpers

  defp capture_frame(c) do
    if VideoCapture.isOpened(c) do
      # Grab two images since one will be buffered and old.
      # Uses grab/retrieve instead of read so only one frame is decoded.
      VideoCapture.grab(c)
      VideoCapture.grab(c)

      case VideoCapture.retrieve(c) do
        img = %Mat{} ->
          {:ok, img}

        {:error, reason} ->
          {:error, reason}

        false ->
          {:error, :no_frame}
      end
    else
      {:error, {:not_open}}
    end
  end

  defp read_image(path) do
    case Evision.imread(path) do
      img = %Mat{} ->
        {:ok, img}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp crop(img, box = %{top: t}) when is_float(t) and t >= 0.0 and t <= 1.0 do
    new_box = %{box | top: trunc(@frame_height * t)}
    crop(img, new_box)
  end

  defp crop(img, box = %{bottom: b}) when is_float(b) and b >= 0.0 and b <= 1.0 do
    new_box = %{box | bottom: trunc(@frame_height * b)}
    crop(img, new_box)
  end

  defp crop(img, box = %{left: l}) when is_float(l) and l >= 0.0 and l <= 1.0 do
    new_box = %{box | left: trunc(@frame_width * l)}
    crop(img, new_box)
  end

  defp crop(img, box = %{right: r}) when is_float(r) and r >= 0.0 and r <= 1.0 do
    new_box = %{box | right: trunc(@frame_width * r)}
    crop(img, new_box)
  end

  defp crop(img, %{top: t, bottom: b, left: l, right: r}) do
    Mat.roi(img, t..b, l..r)
  end

  # https://github.com/opencv/opencv/blob/91808e64a1bce0cd981db27414b67eb897e7ecc1/modules/imgproc/include/opencv2/imgproc/types_c.h#L478
  @cv_tm_ccoeff_normed 5

  defp find(img, template, confidence) do
    case Evision.matchTemplate(img, template, @cv_tm_ccoeff_normed) do
      match = %Mat{} ->
        {h, w, _chan} = template.shape
        {_min_val, max_val, _min_loc, {x, y}} = Evision.minMaxLoc(match)

        if max_val >= confidence do
          {:ok, %{x1: x, y1: y, x2: y + h, y2: x + w, confidence: max_val, width: w, height: h}}
        else
          {:error, :not_found}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp count(img, template, confidence) do
    case Evision.matchTemplate(img, template, @cv_tm_ccoeff_normed) do
      match = %Mat{} ->
        # The match is a 2D array of confidences where it believes the top-left
        # pixel is the start of the template. 
        # Then counts the number of confidences greater than the given level. 
        # If the confidence is too low, then you may get lots of overlapping 
        # bounds.
        match
        |> Evision.Mat.to_nx()
        |> Nx.to_list()
        |> Enum.flat_map(& &1)
        |> Enum.count(&(&1 > confidence))
        |> then(&{:ok, &1})

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp loop_until_found(capture, template, deadline, confidence, interval) do
    with :lt <- DateTime.compare(DateTime.utc_now(), deadline),
         {:ok, img} <- capture_frame(capture),
         {:ok, box} <- find(img, template, confidence) do
      {:ok, box}
    else
      {:error, :not_found} ->
        Process.sleep(interval)
        loop_until_found(capture, template, deadline, confidence, interval)

      {:error, reason} ->
        {:error, reason}

      x when x in [:eq, :gt] ->
        {:ok, nil}
    end
  end

  defp loop_until_gone(capture, template, deadline, confidence, interval) do
    with {:ok, img} <- capture_frame(capture),
         {:error, :not_found} <- find(img, template, confidence) do
      {:ok, nil}
    else
      {:ok, box} ->
        if DateTime.compare(DateTime.utc_now(), deadline) == :lt do
          Process.sleep(interval)
          loop_until_gone(capture, template, deadline, confidence, interval)
        else
          {:ok, box}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end
end
