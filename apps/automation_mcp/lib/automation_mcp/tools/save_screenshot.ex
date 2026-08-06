defmodule AutomationMCP.Tools.SaveScreenshot do
  @moduledoc """
  Capture a screenshot from the capture card and save it directly to a file
  path on the machine running the server, instead of returning the image
  bytes over MCP.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.CaptureDevice
  alias AutomationMCP.Store

  schema do
    field(:path, :string,
      required: true,
      description:
        "Destination file path (e.g. ~/Downloads/screenshot.png) on the server's machine"
    )

    field(:timeout_ms, :integer,
      default: 5000,
      description: "How long to wait for the capture, in milliseconds"
    )
  end

  @impl true
  def execute(%{path: path, timeout_ms: timeout_ms}, frame) do
    if CaptureDevice.available?() do
      capture(path, timeout_ms, frame)
    else
      {:reply, Response.error(Response.tool(), "Capture device is not available"), frame}
    end
  end

  defp capture(path, timeout_ms, frame) do
    full_path = Path.expand(path)
    Vision.Native.capture(full_path)

    case Store.wait_for_file(full_path, timeout_ms) do
      :ok ->
        {:reply, Response.text(Response.tool(), "Saved screenshot to #{full_path}"), frame}

      :timeout ->
        {:reply, Response.error(Response.tool(), "Timed out waiting for capture"), frame}
    end
  end
end
