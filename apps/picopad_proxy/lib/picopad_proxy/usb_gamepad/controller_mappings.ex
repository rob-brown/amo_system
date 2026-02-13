defmodule PicopadProxy.UsbGamepad.ControllerMappings do
  @moduledoc """
  Button mappings for different controller types.
  Maps controller buttons to Nintendo Switch button names.

  Confirmed to work with the follwing controllers:

  * Xbox 360
  * PS5 DualSense
  * PS5 DualSense Edge
  * Gulikit King Kong Pro 2 (not Pro Controller mode)
  * PDP Faceoff Deluxe+ Audio Wired Controller for Nintendo Switch

  Confirmed does **not** work with the following:

  * Nintendo Switch Pro Controller
  * NSO GameCube Controller
  """

  # Default mapping: straight position-based conversion from GilRs to Switch
  @default_mapping %{
    "south" => :b,
    "east" => :a,
    "north" => :x,
    "west" => :y,
    "left_trigger" => :l,
    "right_trigger" => :r,
    "left_trigger2" => :zl,
    "right_trigger2" => :zr,
    "select" => :minus,
    "start" => :plus,
    "mode" => :home,
    "left_thumb" => :l_stick,
    "right_thumb" => :r_stick,
    "dpad_up" => :up,
    "dpad_down" => :down,
    "dpad_left" => :left,
    "dpad_right" => :right,
    "c" => :capture,
    "unknown" => %{}
  }

  @faceoff_mapping %{
    @default_mapping
    | "south" => :y,
      "east" => :b,
      "north" => :l,
      "west" => :x,
      "left_trigger" => :zl,
      "right_trigger" => :zr,
      "left_trigger2" => :minus,
      "right_trigger2" => :plus,
      "select" => :l_stick,
      "start" => :r_stick,
      "mode" => :home,
      "left_thumb" => :capture,
      "unknown" => %{
        589_827 => :a,
        589_830 => :r
      }
  }

  @gulikit_mapping %{
    @default_mapping
    | "east" => :a,
      "north" => :l,
      "west" => :x,
      "left_trigger" => :zl,
      "right_trigger" => :zr,
      "left_trigger2" => :minus,
      "right_trigger2" => :plus,
      "select" => :l_stick,
      "start" => :r_stick,
      "unknown" => %{
        589_827 => :y
      }
  }

  @doc """
  Select button mapping based on controller name.
  Returns a map of GilRs button names to Switch button names.
  """
  def get_button_mapping(controller_name) when is_binary(controller_name) do
    cond do
      controller_name =~ ~r/Gulikit/i -> @gulikit_mapping
      controller_name =~ ~r/Faceoff/i -> @faceoff_mapping
      true -> @default_mapping
    end
  end

  def get_button_mapping(_), do: @default_mapping

  @doc """
  Determine if Y-axis should be inverted for the given controller.
  Returns true if Y-axis values should be negated.
  """
  def invert_y_axis?(controller_name) when is_binary(controller_name) do
    cond do
      controller_name =~ ~r/Xbox 360/i -> true
      true -> false
    end
  end

  def invert_y_axis?(_), do: false
end
