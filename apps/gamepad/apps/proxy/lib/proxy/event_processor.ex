defmodule Proxy.EventProcessor do
  require Logger

  alias Gamepad.InputTracker

  @key_event 1
  @abs_event 3

  @events [@key_event, @abs_event]

  def process(type, code, value, mapping)
      when type in @events and is_integer(code) and is_integer(value) do
    case Map.get(mapping, code, nil) do
      nil ->
        Logger.warning("Unhandled code #{inspect({type, code, value})}")
        :ok

      action ->
        process_action(action, value)
    end
  end

  def process(type, code, value, _mapping) do
    Logger.warning("Unhandled event #{inspect({type, code, value})}")
  end

  defp process_action({:button, button}, value) do
    if value == 0 do
      InputTracker.release_buttons(button)
    else
      InputTracker.hold_buttons(button)
    end
  end

  defp process_action(action, value) when action in [{:pad, "dx"}, {:stick, "lx"}] do
    cond do
      value in 108..148 ->
        InputTracker.release_buttons(["up", "down"])

      value < 108 ->
        InputTracker.hold_buttons(["up"])
        InputTracker.release_buttons(["down"])

      value > 148 ->
        InputTracker.hold_buttons(["down"])
        InputTracker.release_buttons(["up"])
    end
  end

  defp process_action(action, value) when action in [{:pad, "dy"}, {:stick, "ly"}] do
    cond do
      value in 108..148 ->
        InputTracker.release_buttons(["left", "right"])

      value < 108 ->
        InputTracker.hold_buttons(["left"])
        InputTracker.release_buttons(["right"])

      value > 148 ->
        InputTracker.hold_buttons(["right"])
        InputTracker.release_buttons(["left"])
    end
  end

  defp process_action(action, _value) when action in [{:stick, "rx"}, {:stick, "ry"}] do
    # Ignored
    :ok
  end

  defp process_action(action, _value) do
    Logger.warning("Unhandled action #{action}")
  end
end
