defmodule AutomationMCP.Tools.ConnectionStatus do
  @moduledoc "Get the current Picopad USB connection status."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector

  schema do
    %{}
  end

  @impl true
  def execute(_params, frame) do
    status = Connector.status()

    payload = %{
      status: status.status,
      port: status.port,
      player_number: status.player_number,
      last_error: status.last_error
    }

    {:reply, Response.json(Response.tool(), payload), frame}
  end
end
