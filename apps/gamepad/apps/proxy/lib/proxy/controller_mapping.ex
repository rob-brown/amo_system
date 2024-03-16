defmodule Proxy.ControllerMapping do
  def default_mapping(name) do
    case name do
      "Performance Designed Products" <> _ -> pdp_mapping()
      "Nintendo Co., Ltd. Pro Controller" -> pro_controller_mapping()
      "Microsoft X-Box" <> _ -> xbox_mapping()
      "ZhiXu GuliKit Controller A" -> gulikit_android_mapping()
      "ZhiXu GuliKit Controller D" -> gulikit_desktop_mapping()
      "Sony Interactive Entertainment DualSense Wireless Controller" -> dualsense_mapping()
      "Sony Interactive Entertainment DualSense Edge Wireless Controller" -> dualsense_edge_mapping()
      _name -> %{}
    end
  end

  defp pdp_mapping() do
    %{
      0 => {:stick, "lx", 0, 255, 15},
      1 => {:stick, "ly", 0, 255, 15},
      2 => {:stick, "rx", 0, 255, 15},
      5 => {:stick, "ry", 0, 255, 15},
      16 => {:pad, "dx", -1, 1, 0},
      17 => {:pad, "dy", -1, 1, 0},
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
    }
  end

  defp pro_controller_mapping() do
    # This is a guess based on the capabilities reported.
    %{
      0 => {:stick, "lx", 0, 65_535, 4095},
      1 => {:stick, "ly", 0, 65_535, 4095},
      2 => {:stick, "rx", 0, 65_535, 4095},
      5 => {:stick, "ry", 0, 65_535, 4095},
      16 => {:pad, "dx", -1, 1, 0},
      17 => {:pad, "dy", -1, 1, 0},
      288 => {:button, "y"},
      289 => {:button, "b"},
      290 => {:button, "a"},
      291 => {:button, "x"},
      292 => {:button, "l"},
      293 => {:button, "r"},
      294 => {:button, "zl"},
      295 => {:button, "zr"},
      296 => {:button, "minus"},
      297 => {:button, "plus"},
      298 => {:button, "l_stick"},
      299 => {:button, "r_stick"},
      300 => {:button, "home"},
      301 => {:button, "capture"},
    }
  end

  defp xbox_mapping() do
    %{
      0 => {:stick, "lx", -32_768, 32_768, 128},
      1 => {:stick, "ly", -32_768, 32_768, 128},
      # ZL and ZR are analog.
      2 => {:button, "zl"},
      3 => {:stick, "rx", -32_768, 32_768, 128},
      4 => {:stick, "ry", -32_768, 32_768, 128},
      5 => {:button, "zr"},
      16 => {:pad, "dx", -1, 1, 0},
      17 => {:pad, "dy", -1, 1, 0},
      # A/B and X/Y use Nintendo layout.
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
    }
  end

  defp gulikit_android_mapping() do
    %{
      0 => {:stick, "lx", 0, 255, 15},
      1 => {:stick, "ly", 0, 255, 15},
      2 => {:stick, "rx", 0, 255, 15},
      5 => {:stick, "ry", 0, 255, 15},
      # ZL and ZR are analog.
      9 => {:button, "zr"},
      10 => {:button, "zl"},
      16 => {:pad, "dx", -1, 1, 0},
      17 => {:pad, "dy", -1, 1, 0},
      172 => {:button, "home"},
      304 => {:button, "b"},
      305 => {:button, "a"},
      307 => {:button, "y"},
      308 => {:button, "x"},
      310 => {:button, "l"},
      311 => {:button, "r"},
      314 => {:button, "minus"},
      315 => {:button, "plus"},
      317 => {:button, "l_stick"},
      318 => {:button, "r_stick"},
    }
  end

  defp gulikit_desktop_mapping() do
    %{
      0 => {:stick, "lx", 0, 255, 15},
      1 => {:stick, "ly", 0, 255, 15},
      2 => {:stick, "rx", 0, 255, 15},
      5 => {:stick, "ry", 0, 255, 15},
      16 => {:pad, "dx", -1, 1, 0},
      17 => {:pad, "dy", -1, 1, 0},
      288 => {:button, "b"},
      289 => {:button, "a"},
      290 => {:button, "y"},
      291 => {:button, "x"},
      292 => {:button, "l"},
      293 => {:button, "r"},
      294 => {:button, "zr"},
      295 => {:button, "zl"},
      296 => {:button, "minus"},
      297 => {:button, "plus"},
      298 => {:button, "l_stick"},
      299 => {:button, "r_stick"},
      # No home button.
    }
  end

  defp dualsense_mapping() do
    %{
      # Controller says deadzone is 0 but we'll be forgiving.
      0 => {:stick, "lx", 0, 255, 15},
      1 => {:stick, "ly", 0, 255, 15},
      # L2 and R2 are analog.
      2 => {:button, "zl"},
      3 => {:stick, "rx", 0, 255, 15},
      4 => {:stick, "ry", 0, 255, 15},
      5 => {:button, "zr"},
      16 => {:pad, "dx", -1, 1, 0},
      17 => {:pad, "dy", -1, 1, 0},
      # A/B and X/Y set to use Nintendo layout.
      304 => {:button, "b"},
      305 => {:button, "a"},
      307 => {:button, "x"},
      308 => {:button, "y"},
      310 => {:button, "l"},
      311 => {:button, "r"},
      314 => {:button, "capture"},
      315 => {:button, "plus"},
      316 => {:button, "home"},
      317 => {:button, "l_stick"},
      318 => {:button, "r_stick"},
    }
  end

  defp dualsense_edge_mapping() do
    %{
      0 => {:stick, "lx", 0, 255, 15},
      1 => {:stick, "ly", 0, 255, 15},
      2 => {:stick, "rx", 0, 255, 15},
      # L2 and R2 are analog.
      3 => {:button, "zl"},
      4 => {:button, "zr"},
      5 => {:stick, "ry", 0, 255, 15},
      16 => {:pad, "dx", -1, 1, 0},
      17 => {:pad, "dy", -1, 1, 0},
      # A/B and X/Y set to use Nintendo layout.
      304 => {:button, "y"},
      305 => {:button, "b"},
      306 => {:button, "a"},
      307 => {:button, "x"},
      308 => {:button, "l"},
      309 => {:button, "r"},
      312 => {:button, "capture"},
      313 => {:button, "plus"},
      314 => {:button, "l_stick"},
      315 => {:button, "r_stick"},
      316 => {:button, "home"},
      # This is the touch pad.
      317 => {:button, "minus"},
    }
  end
end
