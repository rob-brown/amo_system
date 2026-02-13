defmodule PicopadProxy.UsbGamepad.EventProcessor do
  alias PicopadProxy.InputTracker
  alias PicopadProxy.UsbGamepad.ControllerMappings

  @axis_config %{
    "left_stick_x" => {:stick, :left, :h, {0, 65535, 8000}},
    "left_stick_y" => {:stick, :left, :v, {0, 65535, 8000}},
    "right_stick_x" => {:stick, :right, :h, {0, 65535, 8000}},
    "right_stick_y" => {:stick, :right, :v, {0, 65535, 8000}}
  }

  def process_event(
        %{event_type: "button_pressed", button: button, button_code: code},
        controller_name
      ) do
    button_mapping = ControllerMappings.get_button_mapping(controller_name)

    switch_button =
      if button == "unknown" do
        button_mapping
        |> Map.get("unknown", %{})
        |> Map.get(code, nil)
      else 
        Map.get(button_mapping, button)
      end

    case switch_button do
      nil -> :ok
      mapped -> InputTracker.hold_buttons(mapped)
    end
  end

  def process_event(
        %{event_type: "button_released", button: button, button_code: code},
        controller_name
      ) do
    button_mapping = ControllerMappings.get_button_mapping(controller_name)

    switch_button =
      if button == "unknown" do
        button_mapping
        |> Map.get("unknown", %{})
        |> Map.get(code, nil)
      else 
        Map.get(button_mapping, button)
      end

    case switch_button do
      nil -> :ok
      mapped -> InputTracker.release_buttons(mapped)
    end
  end

  def process_event(%{event_type: "axis_changed", axis: axis, value: value}, controller_name) do
    case Map.get(@axis_config, axis) do
      nil ->
        :ok

      {:stick, stick, direction, {min, max, deadzone}} ->
        should_invert =
          String.ends_with?(axis, "_y") and ControllerMappings.invert_y_axis?(controller_name)

        inverted_value = if should_invert, do: -value, else: value
        scaled_value = scale_axis_value(inverted_value, min, max)

        InputTracker.move_stick(stick, {direction, scaled_value}, {min, max, deadzone},
          report: true
        )
    end
  end

  def process_event(%{event_type: event_type}, _controller_name)
      when event_type in ["connected", "disconnected"] do
    :ok
  end

  def process_event(_event, _controller_name) do
    :ok
  end

  defp scale_axis_value(value, _min, max) when value >= -1.0 and value <= 1.0 do
    trunc((value + 1.0) / 2.0 * max)
  end
end
