defmodule AutomationMCP.Tools.ListImages do
  @moduledoc "List the template images stored on the server for vision matching."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    %{}
  end

  @impl true
  def execute(_params, frame) do
    {:reply, Response.json(Response.tool(), %{images: Store.list_images()}), frame}
  end
end
