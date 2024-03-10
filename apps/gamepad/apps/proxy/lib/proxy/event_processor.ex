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
        Logger.info("Mapped #{inspect({type, code, value})} to #{inspect(action)}")
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

  defp process_action({:pad, "dx"}, value, _mapping) do
    cond do
      value < 0 ->
        InputTracker.hold_buttons(["left"])
        InputTracker.release_buttons(["right"])

      value > 0 ->
        InputTracker.hold_buttons(["right"])
        InputTracker.release_buttons(["left"])

      true ->
        InputTracker.release_buttons(["left", "right"])
    end
  end

  defp process_action({:pad, "dy"}, value, _mapping) do
    cond do
      value < 0 ->
        InputTracker.hold_buttons(["up"])
        InputTracker.release_buttons(["down"])

      value > 0 ->
        InputTracker.hold_buttons(["down"])
        InputTracker.release_buttons(["up"])

      true ->
        InputTracker.release_buttons(["up", "down"])
    end
  end

  defp process_action({:stick, "ly"}, value, mapping) do
    cond do
      value < mapping["up_threshold"] ->
        InputTracker.hold_buttons(["up"])
        InputTracker.release_buttons(["down"])

      value > mapping["down_threshold"] ->
        InputTracker.hold_buttons(["down"])
        InputTracker.release_buttons(["up"])

      true ->
        InputTracker.release_buttons(["up", "down"])

    end
  end

  defp process_action({:stick, "lx"}, value, mapping) do
    cond do
      value < mapping["left_threshold"] ->
        InputTracker.hold_buttons(["left"])
        InputTracker.release_buttons(["right"])

      value > mapping["right_threshold"] ->
        InputTracker.hold_buttons(["right"])
        InputTracker.release_buttons(["left"])

      true ->
        InputTracker.release_buttons(["left", "right"])
    end
  end

  defp process_action(action, _value, _mapping) when action in [{:stick, "rx"}, {:stick, "ry"}] do
    # Ignored
    :ok
  end

  defp process_action(action, _value, _mapping) do
    Logger.warning("Unhandled action #{action}")
  end
end
