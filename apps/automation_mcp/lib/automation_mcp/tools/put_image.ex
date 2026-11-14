defmodule AutomationMCP.Tools.PutImage do
  @moduledoc "Store a base64-encoded PNG template image for later vision matching."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    field(:name, :string, required: true, description: "Image name")
    field(:data, :string, required: true, description: "Base64-encoded PNG bytes")
  end

  @impl true
  def execute(%{name: name, data: data}, frame) do
    case Base.decode64(data) do
      {:ok, bytes} ->
        File.write!(Store.image_path(name), bytes)
        {:reply, Response.text(Response.tool(), "Saved #{name}"), frame}

      :error ->
        {:reply, Response.error(Response.tool(), "Invalid base64 data"), frame}
    end
  end
end
