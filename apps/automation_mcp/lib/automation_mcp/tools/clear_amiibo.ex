defmodule AutomationMCP.Tools.ClearAmiibo do
  @moduledoc "Clear the amiibo currently loaded into the Picopad, if any."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector

  schema do
    %{}
  end

  @impl true
  def execute(_params, frame) do
    case Connector.clear_amiibo() do
      :ok -> {:reply, Response.text(Response.tool(), "Cleared amiibo"), frame}
      {:error, reason} -> {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end
end
