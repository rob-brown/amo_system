defmodule Vision do
  use GenServer

  require Logger

  @enforce_keys [:port, :callers]
  defstruct [:port, :callers]

  @name __MODULE__

  def quit() do
    command = "quit\n"
    GenServer.cast(@name, {:command, command, []})
  end

  def capture(save_file, options \\ []) when is_binary(save_file) do
    path = Path.expand(save_file)
    command = "capture #{path}\n"
    GenServer.cast(@name, {:command, command, options})
  end

  def capture_crop(save_file, {top, left}, {bottom, right}, options \\ [])
      when is_binary(save_file) do
    path = Path.expand(save_file)
    command = "capture_crop #{path} #{top} #{left} #{bottom} #{right}\n"
    GenServer.cast(@name, {:command, command, options})
  end

  def visible(image_file, options \\ []) when is_binary(image_file) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    confidence = Keyword.get(options, :confidence, 0.8)
    command = "visible #{path} #{confidence}\n"
    GenServer.call(@name, {:command, command, options}, timeout)
  end

  def count(image_file, options \\ []) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    confidence = Keyword.get(options, :confidence, 0.89)
    command = "count #{path} #{confidence}\n"
    GenServer.call(@name, {:command, command, options}, timeout)
  end

  def count_crop(image_file, crop, options \\ []) when is_binary(image_file) and is_map(crop) do
    timeout = Keyword.get(options, :timeout, 5000)
    path = Path.expand(image_file)
    top = Map.get(crop, :top, 0.0)
    left = Map.get(crop, :left, 0.0)
    bottom = Map.get(crop, :bottom, 1.0)
    right = Map.get(crop, :right, 1.0)
    confidence = Keyword.get(options, :confidence, 0.89)
    command = "count_crop #{path} #{top} #{left} #{bottom} #{right} #{confidence}\n"
    GenServer.call(@name, {:command, command, options}, timeout)
  end

  def wait_until_found(image_file, duration, options \\ [])
      when is_binary(image_file) and is_number(duration) do
    timeout = Keyword.get(options, :timeout, :infinity)
    path = Path.expand(image_file)
    timeout = timeout || duration + 5000
    command = "find #{path} #{div(duration, 1000)}\n"
    GenServer.call(@name, {:command, command, options}, timeout)
  end

  def wait_until_gone(image_file, duration, options \\ [])
      when is_binary(image_file) and is_number(duration) do
    timeout = Keyword.get(options, :timeout, :infinity)
    path = Path.expand(image_file)
    timeout = timeout || duration + 5000
    command = "gone #{path} #{div(duration, 1000)}\n"
    GenServer.call(@name, {:command, command, options}, timeout)
  end

  def pixels(coordinates, options \\ []) do
    timeout = Keyword.get(options, :timeout, 5000)

    args =
      coordinates
      |> Enum.map(fn {x, y} -> "#{x},#{y}" end)
      |> Enum.join("\t")

    command = "pixels #{args}\n"
    GenServer.call(@name, {:command, command, options}, timeout)
  end

  ## GenServer

  def start_link(_ \\ :ok) do
    GenServer.start_link(__MODULE__, [:ok], name: @name)
  end

  def init(_) do
    {:ok, %__MODULE__{port: open_port(), callers: []}}
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [:ok]}
    }
  end

  def handle_cast({:command, command, options}, state) do
    msg = "sending #{inspect(command)}"

    if Keyword.get(options, :should_log?, true) do
      Logger.debug(msg)
    end

    Port.command(state.port, command)
    {:noreply, state}
  end

  def handle_call({:command, command, options}, from, state) do
    msg = "sending #{inspect(command)}"

    if Keyword.get(options, :should_log?, true) do
      Logger.debug(msg)
    end

    Port.command(state.port, command)
    callback = %{caller: from, options: options}
    new_state = %__MODULE__{state | callers: state.callers ++ [callback]}
    {:noreply, new_state}
  end

  def handle_info({_port, {:data, "Success" <> _}}, state) do
    {:noreply, state}
  end

  def handle_info({_port, {:data, data}}, state = %__MODULE__{callers: [callback | rest]}) do
    if Keyword.get(callback.options, :should_log?, true) do
      _ = Logger.debug("[VISION] #{inspect(data)}")
    end

    response = data |> String.trim() |> String.split("\t") |> process_data()
    GenServer.reply(callback.caller, response)
    new_state = %__MODULE__{state | callers: rest}

    {:noreply, new_state}
  end

  def handle_info({_port, {:exit_status, 0}}, state) do
    _ = Logger.debug("Vision exited normally")
    {:stop, :normal, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    _ = Logger.error("Vision exited: #{code}")
    {:stop, code, state}
  end

  def terminate(reason, state) do
    _ = Logger.warning("Vision terminating because #{inspect(reason)}")
    Port.close(state.port)
  end

  ## Helpers

  defp process_data(["Error", reason]) do
    {:error, reason}
  end

  defp process_data(["Count", count]) do
    count |> String.trim() |> String.to_integer() |> then(&{:ok, &1})
  end

  defp process_data(["None"]) do
    {:ok, nil}
  end

  defp process_data(["Found", x1, y1, x2, y2, confidence, width, height]) do
    data = %{
      x1: String.to_integer(x1),
      y1: String.to_integer(y1),
      x2: String.to_integer(x2),
      y2: String.to_integer(y2),
      confidence: String.to_float(confidence),
      width: String.to_integer(width),
      height: String.to_integer(height)
    }

    {:ok, data}
  end

  defp process_data(["Pixels" | rest]) do
    rest
    |> Enum.map(fn x ->
      x |> String.split(",") |> Enum.map(&String.to_integer/1) |> List.to_tuple()
    end)
    |> then(&{:ok, &1})
  end

  defp open_port() do
    # options = [:stderr_to_stdout, :binary, :exit_status, :use_stdio, :hide]
    options = [:binary, :exit_status, :use_stdio, :hide]
    Port.open({:spawn_executable, executable()}, options)
  end

  defp executable() do
    :vision
    |> :code.priv_dir()
    |> Path.join("vision.py")
    |> Path.expand()
  end
end
