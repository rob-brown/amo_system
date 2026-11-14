defmodule AutomationMCP.Tools.HoldButtons do
  @moduledoc "Hold down a set of controller buttons until released."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector
  alias AutomationMCP.Tools.Buttons

  schema do
    field(:buttons, {:list, :string},
      required: true,
      description: "Buttons to hold, e.g. [\"a\", \"zr\"]"
    )
  end

  @impl true
  def execute(%{buttons: buttons}, frame) do
    case Buttons.to_atoms(buttons) do
      {:ok, atoms} ->
        case Connector.hold(atoms) do
          :ok ->
            {:reply, Response.text(Response.tool(), "Holding #{Enum.join(buttons, ", ")}"), frame}

          {:error, reason} ->
            {:reply, Response.error(Response.tool(), inspect(reason)), frame}
        end

      {:error, reason} ->
        {:reply, Response.error(Response.tool(), reason), frame}
    end
  end
end
