defmodule AutomationMCP.Tools.ImageVisible do
  @moduledoc "Check whether a stored template image is currently visible on screen."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    field(:name, :string, required: true, description: "Image name")

    field(:timeout_ms, :integer,
      default: 5000,
      description: "How long to wait for a match, in milliseconds"
    )

    field(:confidence, :number, default: 0.8, description: "Minimum match confidence, 0.0-1.0")
  end

  @impl true
  def execute(%{name: name, timeout_ms: timeout_ms, confidence: confidence}, frame) do
    with {:ok, path} <- Store.lookup_image(name) do
      opts = [timeout: timeout_ms, confidence: confidence]

      case Vision.Native.visible(path, opts) do
        {:ok, info} ->
          {:reply, Response.json(Response.tool(), %{visible: true, info: info}), frame}

        {:error, :not_found} ->
          {:reply, Response.json(Response.tool(), %{visible: false, info: nil}), frame}

        {:error, reason} ->
          {:reply, Response.error(Response.tool(), inspect(reason)), frame}
      end
    else
      {:error, reason} -> {:reply, Response.error(Response.tool(), reason), frame}
    end
  end
end
