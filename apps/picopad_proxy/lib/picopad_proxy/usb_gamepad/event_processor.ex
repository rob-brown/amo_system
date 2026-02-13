defmodule PicopadProxy.UsbGamepad.EventProcessor do
  require Logger

  alias PicopadProxy.InputTracker

  @button_mapping %{
    # Faceoff Deluxe+ has non-standard mapping:
    # Physical B → "east", Physical X → "west", Physical Y → "south", Physical L → "north"
    "south" => "y",
    "east" => "b",
    "north" => "l",
    "west" => "x",
    # Triggers are correct
    "left_trigger" => "zl",
    "right_trigger" => "zr",
    # Plus/Minus use trigger2 names (actual +/- buttons on controller)
    "left_trigger2" => "minus",
    "right_trigger2" => "plus",
    # Stick clicks (L3/R3) use select/start names
    "select" => "l_stick",
    "start" => "r_stick",
    "mode" => "home",
    "left_thumb" => "l_stick",
    "right_thumb" => "r_stick",
    # D-pad
    "dpad_up" => "up",
    "dpad_down" => "down",
    "dpad_left" => "left",
    "dpad_right" => "right",
    "c" => "capture"
  }

  @axis_config %{
    "left_stick_x" => {:stick, :left, :h, {0, 65535, 8000}},
    "left_stick_y" => {:stick, :left, :v, {0, 65535, 8000}},
    "right_stick_x" => {:stick, :right, :h, {0, 65535, 8000}},
    "right_stick_y" => {:stick, :right, :v, {0, 65535, 8000}}
  }

  def process_event(%{event_type: "button_pressed", button: button, button_code: code}) do
    switch_button =
      case button do
        "unknown" ->
          case code do
            589_827 -> "a"
            589_830 -> "r"
            _ -> nil
          end

        "left_thumb" ->
          case code do
            589_838 -> "capture"
            _ -> Map.get(@button_mapping, button)
          end

        _ ->
          Map.get(@button_mapping, button)
      end

    case switch_button do
      nil -> :ok
      mapped -> InputTracker.hold_buttons(mapped)
    end
  end

  def process_event(%{event_type: "button_released", button: button, button_code: code}) do
    switch_button =
      case button do
        "unknown" ->
          case code do
            589_827 -> "a"
            589_830 -> "r"
            _ -> nil
          end

        "left_thumb" ->
          case code do
            589_838 -> "capture"
            _ -> Map.get(@button_mapping, button)
          end

        _ ->
          Map.get(@button_mapping, button)
      end

    case switch_button do
      nil -> :ok
      mapped -> InputTracker.release_buttons(mapped)
    end
  end

  def process_event(%{event_type: "axis_changed", axis: axis, value: value}) do
    case Map.get(@axis_config, axis) do
      nil ->
        :ok

      {:stick, stick, direction, {min, max, deadzone}} ->
        scaled_value = scale_axis_value(value, min, max)

        InputTracker.move_stick(stick, {direction, scaled_value}, {min, max, deadzone},
          report: true
        )
    end
  end

  def process_event(%{event_type: event_type}) when event_type in ["connected", "disconnected"] do
    :ok
  end

  def process_event(_event) do
    :ok
  end

  defp scale_axis_value(value, _min, max) when value >= -1.0 and value <= 1.0 do
    trunc((value + 1.0) / 2.0 * max)
  end
end
