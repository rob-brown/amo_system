import Config

config :autopilot, :gamepad_module, AutomationMCP.Gamepad

# Name substrings (case-insensitive) used to find the capture card among the
# OS's enumerated cameras, tried in priority order. The numeric OpenCV index
# isn't used directly because it reflects enumeration order, which shifts
# depending on what's plugged in and even across replugs of the same device
# — see AutomationMCP.CaptureDeviceFinder. Add other capture cards you use
# to this list; the first pattern with a matching device wins.
config :automation_mcp, :capture_device_names, ["ShadowCast"]
