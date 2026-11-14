defmodule AutomationMCP.Tools.ReleaseAllButtons do
  @moduledoc "Release every currently held controller button and center both sticks."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector

  schema do
    %{}
  end

  @impl true
  def execute(_params, frame) do
    case Connector.release_all() do
      :ok -> {:reply, Response.text(Response.tool(), "Released all buttons"), frame}
      {:error, reason} -> {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end
end
