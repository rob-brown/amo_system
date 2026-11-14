defmodule AutomationMCP.Tools.DeleteScript do
  @moduledoc "Delete a stored Lua automation script by name."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    field(:name, :string, required: true, description: "Script name")
  end

  @impl true
  def execute(%{name: name}, frame) do
    case Store.lookup_script(name) do
      {:ok, path} ->
        File.rm!(path)
        {:reply, Response.text(Response.tool(), "Deleted #{name}"), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), reason), frame}
    end
  end
end
