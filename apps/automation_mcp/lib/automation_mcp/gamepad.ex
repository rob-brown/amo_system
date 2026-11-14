defmodule AutomationMCP.Gamepad do
  @moduledoc """
  Adapts `AutomationMCP.Connector` to the `Autopilot.Gamepad` behaviour so
  that Lua scripts run through `Autopilot.LuaScript` can drive the Picopad.
  """

  @behaviour Autopilot.Gamepad

  alias AutomationMCP.Connector

  @impl true
  def press(button, duration) when is_binary(button) do
    Connector.press(String.to_existing_atom(button), duration)
  end

  @impl true
  def load_amiibo(data) when is_binary(data) do
    Connector.load_amiibo(data)
  end

  @impl true
  def clear_amiibo do
    Connector.clear_amiibo()
  end
end
