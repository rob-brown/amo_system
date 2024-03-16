defmodule Proxy.EventProcessor do
  require Logger

  alias Gamepad.InputTracker

  @sync_event 0
  @key_event 1
  @absolute_event 3

  @events [@sync_event, @key_event, @absolute_event]

  def process(0, 0, 0, _mapping) do
    InputTracker.report()
  end

  def process(type, code, value, mapping)
      when type in @events and is_integer(code) and is_integer(value) do
    case Map.get(mapping, code, nil) do
      nil ->
        Logger.warning("Unhandled code #{inspect({type, code, value})}")
        :ok

      action ->
        # Logger.info("Mapped #{inspect({type, code, value})} to #{inspect(action)}")
        process_action(action, value, mapping)
    end
  end

  def process(type, code, value, _mapping) do
    Logger.warning("Unhandled event #{inspect({type, code, value})}")
  end

  defp process_action({:button, button}, value, _mapping) do
    if value == 0 do
      InputTracker.release_buttons(button)
    else
      InputTracker.hold_buttons(button)
    end
  end

  defp process_action({:pad, "dx", _min, _max, _deadzone}, value, _mapping) do
    cond do
      value < 0 ->
        InputTracker.update_buttons(["left"], ["right"])

      value > 0 ->
        InputTracker.update_buttons(["right"], ["left"])

      true ->
        InputTracker.release_buttons(["left", "right"])
    end
  end

  defp process_action({:pad, "dy", _min, _max, _deadzone}, value, _mapping) do
    cond do
      value < 0 ->
        InputTracker.update_buttons(["up"], ["down"])

      value > 0 ->
        InputTracker.update_buttons(["down"], ["up"])

      true ->
        InputTracker.release_buttons(["up", "down"])
    end
  end

  defp process_action({:stick, "ly", min, max, deadzone}, value, _mapping) do
    InputTracker.move_stick(:left, {:v, value}, {min, max, deadzone}, report: false)
  end

  defp process_action({:stick, "lx", min, max, deadzone}, value, _mapping) do
    InputTracker.move_stick(:left, {:h, value}, {min, max, deadzone}, report: false)
  end

  defp process_action({:stick, "ry", min, max, deadzone}, value, _mapping) do
    InputTracker.move_stick(:right, {:v, value}, {min, max, deadzone}, report: false)
  end

  defp process_action({:stick, "rx", min, max, deadzone}, value, _mapping) do
    InputTracker.move_stick(:right, {:h, value}, {min, max, deadzone}, report: false)
  end

  defp process_action(action, _value, _mapping) do
    Logger.warning("Unhandled action #{action}")
  end
end
