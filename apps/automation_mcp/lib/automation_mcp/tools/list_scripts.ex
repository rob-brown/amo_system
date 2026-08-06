defmodule AutomationMCP.Tools.ListScripts do
  @moduledoc "List the Lua automation scripts stored on the server."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    %{}
  end

  @impl true
  def execute(_params, frame) do
    {:reply, Response.json(Response.tool(), %{scripts: Store.list_scripts()}), frame}
  end
end
