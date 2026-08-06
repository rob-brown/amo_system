defmodule AutomationMCP.Tools.PressButton do
  @moduledoc "Press a single controller button for a duration, then release it."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector
  alias AutomationMCP.Tools.Buttons

  schema do
    field(:button, :enum, values: Buttons.valid(), required: true, description: "Button to press")

    field(:duration_ms, :integer,
      default: 50,
      description: "How long to hold the button, in milliseconds"
    )
  end

  @impl true
  def execute(%{button: button, duration_ms: duration_ms}, frame) do
    case Connector.press(String.to_existing_atom(button), duration_ms) do
      :ok -> {:reply, Response.text(Response.tool(), "Pressed #{button}"), frame}
      {:error, reason} -> {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end
end
