defmodule Proxy.Constant do
  # See https://www.kernel.org/doc/html/latest/input/event-codes.html
  @mappings %{
    # SYN = synchronization
    # Used as markers to separate events in time or space
    # TODO: Handle synchronization for better joystick control
    "EV_SYN" => 0,
    "EV_KEY" => 1,
    # REL = relative (ex. mouse wheel)
    "EV_REL" => 2,
    # ABS = absolute (ex. joystick)
    "EV_ABS" => 3,
    # MSC = miscellaneous
    "EV_MSC" => 4,
    # SW = switch
    "EV_SW" => 5,
    "EV_LED" => 17,
    # SND = sound
    "EV_SND" => 18,
    # REP = repeat
    "EV_REP" => 20,
    # FF = force feedback (ex. rumble)
    "EV_FF" => 21,
    "EV_PWR" => 22,
    "EV_FF_STATUS" => 23,
    "EV_MAX" => 31,
    "EV_CNT" => 32,
    # UINPUT = userland input
    "EV_UINPUT" => 257,
    "EV_VERSION" => 65537
  }
end
