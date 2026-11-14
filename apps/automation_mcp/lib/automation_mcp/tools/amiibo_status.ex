defmodule AutomationMCP.Tools.AmiiboStatus do
  @moduledoc "Get the state of the amiibo currently loaded into the Picopad, if any."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector

  schema do
    %{}
  end

  @impl true
  def execute(_params, frame) do
    case Connector.amiibo_status() do
      {:ok, info} ->
        payload = %{state: info.state, uid: Base.encode16(info.uid), size: info.size}
        {:reply, Response.json(Response.tool(), payload), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end
end
