defmodule AutomationMCP.Tools.Reconnect do
  @moduledoc """
  Disconnect from the current Picopad (if any) and rescan USB serial ports
  for a device that responds to the Picopad protocol.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector

  schema do
    %{}
  end

  @impl true
  def execute(_params, frame) do
    status = Connector.rescan()

    payload = %{
      status: status.status,
      port: status.port,
      player_number: status.player_number,
      last_error: status.last_error
    }

    {:reply, Response.json(Response.tool(), payload), frame}
  end
end
