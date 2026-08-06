import Config

config :autopilot, :gamepad_module, AutomationMCP.Gamepad

# Name substrings (case-insensitive) used to find the capture card among the
# OS's enumerated cameras, tried in priority order. The numeric OpenCV index
# isn't used directly because it reflects enumeration order, which shifts
# depending on what's plugged in and even across replugs of the same device
# — see AutomationMCP.CaptureDeviceFinder. Add other capture cards you use
# to this list; the first pattern with a matching device wins.
config :automation_mcp, :capture_device_names, ["ShadowCast"]

# Requested capture resolution as {width, height}. Not guaranteed — some
# capture cards only support a fixed set of modes and silently ignore an
# unsupported request, keeping whatever resolution was already active.
# AutomationMCP.CaptureDevice logs a warning at startup if the actual
# resolution (checked via Vision.Native.resolution/0) doesn't match this.
# 800x450 (16:9) matches the Switch/Switch 2 UI aspect ratio; use 640x480
# (4:3) for setups built around the original Genki Shadowcast default.
config :automation_mcp, :capture_resolution, {800, 450}
