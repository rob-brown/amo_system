defmodule AutomationMCP.Tools.SetStick do
  @moduledoc """
  Move an analog stick, either to a named preset (e.g. "up", "down_left")
  or to a raw {x, y} axis position.
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector

  @presets ~w(center up down left right up_left up_right down_left down_right)

  schema do
    field(:side, :enum,
      values: ~w(left right),
      required: true,
      description: "Which stick to move"
    )

    field(:preset, :enum, values: @presets, description: "A named stick position")
    field(:x, :integer, description: "Raw horizontal axis value (used when preset is omitted)")
    field(:y, :integer, description: "Raw vertical axis value (used when preset is omitted)")
  end

  @impl true
  def execute(params, frame) do
    side = String.to_existing_atom(params.side)

    result =
      cond do
        params[:preset] -> Connector.stick(side, String.to_existing_atom(params.preset))
        params[:x] && params[:y] -> Connector.stick(side, {params.x, params.y})
        true -> {:error, "Provide either preset or both x and y"}
      end

    case result do
      :ok -> {:reply, Response.text(Response.tool(), "Moved #{params.side} stick"), frame}
      {:error, reason} -> {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end
end
