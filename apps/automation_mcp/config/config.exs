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
#
# 1280x720 (16:9) is a confirmed exact mode on the ShadowCast 2 Pro with a
# Switch 2 connected — 800x450 and 640x480 are not real modes on this
# device and silently snap to 800x600 or 1280x720 instead (probed live via
# the set_resolution/get_resolution tools). Adjust here if you switch
# capture hardware; use the get_resolution/set_resolution tools to
# rediscover the real supported modes rather than guessing.
config :automation_mcp, :capture_resolution, {1280, 720}
