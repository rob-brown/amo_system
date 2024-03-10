defmodule Proxy.ControllerMapping do
  def default_mapping("Performance Designed Products" <> _) do
    pdp_mapping()
  end

  def default_mapping("Nintendo Co., Ltd. Pro Controller") do
    pro_controller_mapping()
  end

  def default_mapping("Microsoft X-Box" <> _) do
    xbox_mapping()
  end

  def default_mapping("ZhiXu GuliKit Controller A") do
    gulikit_android_mapping()
  end

  def default_mapping("ZhiXu GuliKit Controller D") do
    gulikit_desktop_mapping()
  end

  defp pdp_mapping() do
    %{
      0 => {:stick, "lx"},
      1 => {:stick, "ly"},
      2 => {:stick, "rx"},
      5 => {:stick, "ry"},
      16 => {:pad, "dx"},
      17 => {:pad, "dy"},
      304 => {:button, "y"},
      305 => {:button, "b"},
      306 => {:button, "a"},
      307 => {:button, "x"},
      308 => {:button, "l"},
      309 => {:button, "r"},
      310 => {:button, "zl"},
      311 => {:button, "zr"},
      312 => {:button, "minus"},
      313 => {:button, "plus"},
      314 => {:button, "l_stick"},
      315 => {:button, "r_stick"},
      316 => {:button, "home"},
      317 => {:button, "capture"},
      "left_threshold" => 108,
      "right_threshold" => 148,
      "up_threshold" => 108,
      "down_threshold" => 148,
    }
  end

  defp pro_controller_mapping() do
    # TODO:
    %{}
  end

  defp xbox_mapping() do
    # The ZL and ZR buttons are actually analog.
    # At least on the GuliKit controller.
    # Checking for non-zero for pressed will work for both cases.
    %{
      0 => {:stick, "lx"},
      1 => {:stick, "ly"},
      2 => {:button, "zl"},
      3 => {:stick, "rx"},
      4 => {:stick, "ry"},
      5 => {:button, "zr"},
      16 => {:pad, "dx"},
      17 => {:pad, "dy"},
      304 => {:button, "b"},
      305 => {:button, "a"},
      307 => {:button, "y"},
      308 => {:button, "x"},
      310 => {:button, "l"},
      311 => {:button, "r"},
      314 => {:button, "minus"},
      315 => {:button, "plus"},
      316 => {:button, "home"},
      317 => {:button, "l_stick"},
      318 => {:button, "r_stick"},
      "left_threshold" => -5000,
      "right_threshold" => 5000,
      "up_threshold" => -5000,
      "down_threshold" => 5000,
    }
  end

  defp gulikit_android_mapping() do
    # TODO:
    %{}
  end

  defp gulikit_desktop_mapping() do
    # TODO:
    %{}
  end
end
