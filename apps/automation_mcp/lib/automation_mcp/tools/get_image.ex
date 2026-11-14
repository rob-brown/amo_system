defmodule AutomationMCP.Tools.GetImage do
  @moduledoc "Fetch a stored template image by name."

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
        {:reply, Response.image(Response.tool(), Base.encode64(File.read!(path)), "image/png"),
         frame}

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), reason), frame}
    end
  end
end
