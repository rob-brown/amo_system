defmodule RabbitDriver.ImageConsumer do
  @behaviour RabbitDriver.Consumer

  require Logger

  alias RabbitDriver.DataURL

  def start_link(opts) do
    defaults = [
      module: __MODULE__,
      topics: ["image.#"],
      queue: "image_consumer"
    ]

    opts = Keyword.merge(defaults, opts)
    RabbitDriver.Consumer.start_link(opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def image_dir() do
    Path.join(System.tmp_dir(), "rabbit-driver-images")
  end

  @impl RabbitDriver.Consumer
  def init(_opts) do
    _ = File.mkdir_p(image_dir())
    _ = File.mkdir_p(screenshot_dir())
  end

  @impl RabbitDriver.Consumer
  def handle_msg(~w"image list", _payload) do
    {:reply, %{images: images()}}
  end

  def handle_msg(~w"image get", payload) do
    images = images()
    name = Map.get(payload, "name")

    if name in images do
      bytes = name |> path() |> File.read!() |> DataURL.encode("image/png", :base64)

      response = %{
        image: %{
          name: name,
          size: byte_size(bytes),
          bytes: bytes
        }
      }

      {:reply, response}
    else
      {:reply, %{image: nil, error: "Not found"}}
    end
  end

  def handle_msg(~w"image put", %{"name" => name, "bytes" => bytes}) do
    case DataURL.decode(bytes) do
      {:ok, "image/png", _param, bytes} ->
        File.write!(path(name), bytes)
        :noreply

      {:ok, type, _param, _bytes} ->
        Logger.error("Got unsupported image type '#{type}'")
        :noreply

      _ ->
        Logger.error("Unknown image data received")
        :noreply
    end
  end

  def handle_msg(~w"image delete", %{"name" => name}) do
    case lookup(name) do
      {:ok, path} ->
        File.rm!(path)
        :noreply

      _ ->
        :noreply
    end
  end

  def handle_msg(~w"image visible", payload = %{"name" => name}) do
    with {:ok, path} <- lookup(name),
         timeout = Map.get(payload, "timeout_ms", :timer.seconds(5)),
         confidence = Map.get(payload, "confidence", 0.8),
         opts = [timeout: timeout, confidence: confidence],
         {:ok, info} <- visible(path, opts) do
      {:reply, Map.put(info, :error, nil)}
    else
      {:error, reason} ->
        {:reply, %{error: reason}}
    end
  end

  def handle_msg(~w"image count", payload = %{"name" => name}) do
    with {:ok, path} <- lookup(name),
         timeout = Map.get(payload, "timeout_ms", :timer.seconds(5)),
         confidence = Map.get(payload, "confidence", 0.89),
         opts = [timeout: timeout, confidence: confidence],
         {:ok, count} <- Vision.count(path, opts) || {:error, "Not found"} do
      {:reply, %{error: nil, count: count}}
    else
      {:error, reason} ->
        {:reply, %{error: reason}}
    end
  end

  def handle_msg(~w"image screenshot", payload) do
    timeout = Map.get(payload, "timeout_ms", :timer.seconds(5))
    path = temp_path()
    Vision.capture(path)

    result =
      case wait_for_file(path, timeout) do
        {:ok, bytes} ->
          {:reply,
           %{
             screenshot: %{
               type: "image/png",
               size: byte_size(bytes),
               bytes: Base.encode64(bytes)
             }
           }}

        :timeout ->
          {:reply, %{screenshot: nil, error: :timeout}}
      end

    clean_up_file(path)

    result
  end

  def handle_msg(topic, _payload) do
    {:error, "Unknown message #{topic}"}
  end

  ## Helpers
  
  defp visible(path, opts) do
    case Vision.visible(path, opts) do
      {:ok, nil} ->
        {:error, "Not found"}

      {:ok, info = %{}} ->
        {:ok, info}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp lookup(name) do
    path = path(name)

    if File.exists?(path) and File.regular?(path) do
      {:ok, path}
    else
      {:error, "No such file"}
    end
  end

  defp images() do
    File.ls!(image_dir())
  end

  defp screenshot_dir() do
    Path.join(System.tmp_dir(), "rabbit-driver-screenshots")
  end

  defp temp_path() do
    name = RabbitDriver.Random.string() <> ".png"

    Path.join(screenshot_dir(), name)
  end

  defp path(name = <<c::utf8>> <> _) when c in [?~, ?., ?/] do
    raise "Unsafe file name #{name}"
  end

  defp path(name) do
    if String.ends_with?(name, ".png") do
      Path.join(image_dir(), name)
    else
      Path.join(image_dir(), name <> ".png")
    end
  end

  defp wait_for_file(path, timeout, sleep_time \\ 100)

  defp wait_for_file(_path, timeout, _sleep_time) when timeout < 0 do
    :timeout
  end

  defp wait_for_file(path, timeout, sleep_time) do
    if File.regular?(path) do
      {:ok, File.read!(path)}
    else
      Process.sleep(sleep_time)
      wait_for_file(path, timeout - sleep_time, sleep_time)
    end
  end

  defp clean_up_file(path) do
    Task.start(fn ->
      Process.sleep(:timer.seconds(5))
      _ = File.rm(path)
    end)
  end
end
