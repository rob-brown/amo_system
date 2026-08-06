defmodule AutomationMCP.Tools.CountImage do
  @moduledoc "Count how many times a stored template image appears on screen."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    field(:name, :string, required: true, description: "Image name")
    field(:confidence, :number, default: 0.89, description: "Minimum match confidence, 0.0-1.0")
  end

  @impl true
  def execute(%{name: name, confidence: confidence}, frame) do
    with {:ok, path} <- Store.lookup_image(name),
         {:ok, count} <- Vision.Native.count(path, confidence: confidence) do
      {:reply, Response.json(Response.tool(), %{count: count}), frame}
    else
      {:error, reason} -> {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end
end
