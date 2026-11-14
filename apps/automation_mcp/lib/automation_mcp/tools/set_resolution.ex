defmodule AutomationMCP.Tools.SetResolution do
  @moduledoc """
  Request a new capture resolution. Not guaranteed to take effect — some
  capture cards only support a fixed set of modes and silently ignore an
  unsupported request. Always check the returned actual resolution;
  template images must match whatever resolution the device actually ends
  up at.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.CaptureDevice

  schema do
    field(:width, :integer, required: true, description: "Requested frame width")
    field(:height, :integer, required: true, description: "Requested frame height")
  end

  @impl true
  def execute(%{width: width, height: height}, frame) do
    case CaptureDevice.set_resolution(width, height) do
      {:ok, {actual_width, actual_height}} ->
        payload = %{
          requested: %{width: width, height: height},
          actual: %{width: actual_width, height: actual_height},
          matched: {actual_width, actual_height} == {width, height}
        }

        {:reply, Response.json(Response.tool(), payload), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end
end
