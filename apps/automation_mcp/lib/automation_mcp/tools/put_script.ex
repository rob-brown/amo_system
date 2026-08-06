defmodule AutomationMCP.Tools.PutScript do
  @moduledoc "Store a Lua automation script under the given name."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    field(:name, :string, required: true, description: "Script name")
    field(:content, :string, required: true, description: "Lua source code")
  end

  @impl true
  def execute(%{name: name, content: content}, frame) do
    File.write!(Store.script_path(name), content)
    {:reply, Response.text(Response.tool(), "Saved #{name}"), frame}
  end
end
