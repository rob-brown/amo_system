defmodule AutomationMCP.Tools.DeleteImage do
  @moduledoc "Delete a stored template image by name."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    field(:name, :string, required: true, description: "Image name")
  end

  @impl true
  def execute(%{name: name}, frame) do
    case Store.lookup_image(name) do
      {:ok, path} ->
        File.rm!(path)
        {:reply, Response.text(Response.tool(), "Deleted #{name}"), frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), reason), frame}
    end
  end
end
