defmodule AutomationMCP.CaptureDeviceFinderTest do
  use ExUnit.Case, async: true

  alias AutomationMCP.CaptureDeviceFinder

  @sample_output """
  [AVFoundation indev @ 0x8fcc38000] AVFoundation video devices:
  [AVFoundation indev @ 0x8fcc38000] [0] ShadowCast 2 Pro
  [AVFoundation indev @ 0x8fcc38000] [1] OBS Virtual Camera
  [AVFoundation indev @ 0x8fcc38000] [2] Camo Camera
  [AVFoundation indev @ 0x8fcc38000] AVFoundation audio devices:
  [AVFoundation indev @ 0x8fcc38000] [0] MacBook Pro Microphone
  """

  describe "parse_avfoundation/1" do
    test "extracts only the video device section, ignoring the audio section" do
      # Arrange & Act
      devices = CaptureDeviceFinder.parse_avfoundation(@sample_output)

      # Assert
      assert devices == [
               {0, "ShadowCast 2 Pro"},
               {1, "OBS Virtual Camera"},
               {2, "Camo Camera"}
             ]
    end
  end
end
