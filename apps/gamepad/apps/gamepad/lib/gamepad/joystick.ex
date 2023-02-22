defmodule Gamepad.Joystick do
  import Bitwise

  require Logger

  alias Circuits.I2C
  alias Gamepad.InputTracker

  @address 0x48
  @conversion_register 0x0
  @config_register 0x1
  @threshold 10_000
  @offset 14_000

  def start() do
    {:ok, ref} = I2C.open("i2c-1")
    ref
  end

  def listen_forever(ref \\ start(), sample_rate \\ 100) do
    x = read(ref, :x)
    y = read(ref, :y)

    cond do
      x < -@threshold ->
        InputTracker.hold_buttons("up")
        InputTracker.release_buttons("down")

      x > @threshold ->
        InputTracker.hold_buttons("down")
        InputTracker.release_buttons("up")

      true ->
        InputTracker.release_buttons(["up", "down"])
    end

    cond do
      y < -@threshold ->
        InputTracker.hold_buttons("left")
        InputTracker.release_buttons("right")

      y > @threshold ->
        InputTracker.hold_buttons("right")
        InputTracker.release_buttons("left")

      true ->
        InputTracker.release_buttons(["left", "right"])
    end

    listen_forever(ref, sample_rate)
  end

  def read(ref, axis) when axis in [:x, :y] do
    send_config(ref, axis)
    wait_until_ready(ref)
    read_joystick(ref, axis)
  end

  defp axis_to_channel(:x), do: 0x4000
  defp axis_to_channel(:y), do: 0x5000

  def config_data(axis) do
    value =
      axis_to_channel(axis) |||
        (_ADS1015_REG_CONFIG_CQUE_NONE = 0x3) |||
        (_DS1015_REG_CONFIG_CLAT_NONLAT = 0x0) |||
        (_ADS1015_REG_CONFIG_CPOL_ACTVLOW = 0x0) |||
        (_ADS1015_REG_CONFIG_CMODE_TRAD = 0x0) |||
        (_ADS1015_REG_CONFIG_DR_1600SPS = 0x80) |||
        (_ADS1015_REG_CONFIG_MODE_SINGLE = 0x100) |||
        (_ADS1015_REG_CONFIG_GAIN_ONE = 0x200) |||
        (_ADS1015_REG_CONFIG_OS_SINGLE = 0x8000)

    <<value::integer-big-size(16)>>
  end

  defp send_config(ref, axis) do
    I2C.write!(ref, @address, <<@config_register>> <> config_data(axis))
  end

  defp wait_until_ready(ref, retries \\ 10)

  defp wait_until_ready(_ref, 0) do
    Logger.warn("Joystick timeout")
    :timeout
  end

  defp wait_until_ready(ref, retries) do
    case I2C.write_read!(ref, @address, <<@config_register>>, 2) do
      <<1::1, _::bits>> ->
        :ok

      _ ->
        wait_until_ready(ref, retries - 1)
    end
  end

  defp read_joystick(ref, axis) do
    <<value::integer-big-size(16)>> = I2C.write_read!(ref, @address, <<@conversion_register>>, 2)

    # Shift the values so ~0 is center.
    case axis do
      :x ->
        value - @offset

      :y ->
        value - @offset
    end
  end
end
