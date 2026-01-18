defmodule Autopilot.Gamepad do
  @doc """
  Press the given button for the given milliseconds.
  The following are the recognized buttons:

  * a
  * b
  * x
  * y
  * up
  * down
  * left
  * right
  * l
  * r
  * zl
  * zr
  * minus
  * plus
  * r_stick
  * l_stick
  * home
  * capture
  """
  @callback press(button :: binary(), duration :: integer()) :: :ok

  @doc """
  Load the amiibo binary into memory. This is not a file path.
  """
  @callback load_amiibo(binary()) :: :ok

  @doc """
  Clear the current amiibo, if any, from memory.
  """
  @callback clear_amiibo() :: :ok
end
