defmodule AutomationMCP.Tools.GetResolution do
  @moduledoc "Get the capture card's current actual resolution."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.CaptureDevice

  schema do
    %{}
  end

  @impl true
  def execute(_params, frame) do
    case CaptureDevice.resolution() do
      {:ok, {width, height}} ->
        {:reply, Response.json(Response.tool(), %{width: width, height: height}), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end
end
