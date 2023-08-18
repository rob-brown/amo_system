defmodule RabbitDriver.VisionConsumer do
  @behaviour RabbitDriver.Consumer

  def start_link(opts) do
    defaults = [module: __MODULE__, topics: ["vision.#"], queue: "vision_consumer"]
    opts = Keyword.merge(defaults, opts)
    RabbitDriver.Consumer.start_link(opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @impl RabbitDriver.Consumer
  def init(_opts) do
    _ = File.mkdir_p!(screenshot_dir())
  end

  @impl RabbitDriver.Consumer
  def handle_msg(~w"vision screenshot", payload) do
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

  defp screenshot_dir() do
    Path.join(System.tmp_dir(), "rabbit-driver-screenshots")
  end

  defp temp_path() do
    name = RabbitDriver.Random.string() <> ".png"

    Path.join(screenshot_dir(), name)
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
