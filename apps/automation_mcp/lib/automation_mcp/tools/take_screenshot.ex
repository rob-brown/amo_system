defmodule AutomationMCP.Tools.TakeScreenshot do
  @moduledoc "Capture a screenshot from the capture card and return it as a PNG image."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.CaptureDevice
  alias AutomationMCP.Store

  schema do
    field(:timeout_ms, :integer,
      default: 5000,
      description: "How long to wait for the capture, in milliseconds"
    )
  end

  @impl true
  def execute(%{timeout_ms: timeout_ms}, frame) do
    if CaptureDevice.available?() do
      capture(timeout_ms, frame)
    else
      {:reply, Response.error(Response.tool(), "Capture device is not available"), frame}
    end
  end

  defp capture(timeout_ms, frame) do
    path = Store.screenshot_path()
    Vision.Native.capture(path)

    result =
      case wait_for_file(path, timeout_ms) do
        {:ok, bytes} ->
          {:reply, Response.image(Response.tool(), Base.encode64(bytes), "image/png"), frame}

        :timeout ->
          {:reply, Response.error(Response.tool(), "Timed out waiting for capture"), frame}
      end

    Store.cleanup_later(path)
    result
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
end
