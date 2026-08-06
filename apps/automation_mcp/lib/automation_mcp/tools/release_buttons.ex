defmodule AutomationMCP.Tools.ReleaseButtons do
  @moduledoc "Release a set of previously held controller buttons."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector
  alias AutomationMCP.Tools.Buttons

  schema do
    field(:buttons, {:list, :string},
      required: true,
      description: "Buttons to release, e.g. [\"a\", \"zr\"]"
    )
  end

  @impl true
  def execute(%{buttons: buttons}, frame) do
    case Buttons.to_atoms(buttons) do
      {:ok, atoms} ->
        case Connector.release(atoms) do
          :ok ->
            {:reply, Response.text(Response.tool(), "Released #{Enum.join(buttons, ", ")}"),
             frame}

          {:error, reason} ->
            {:reply, Response.error(Response.tool(), inspect(reason)), frame}
        end

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), reason), frame}
    end
  end
end
