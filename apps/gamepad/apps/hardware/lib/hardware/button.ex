defmodule Gamepad.Button do
  require Logger

  def start(platform) when platform in [:joybonnet, :ammobox] do
    for %{gpio_pin: pin} <- pins(platform) do
      {:ok, input} = Circuits.GPIO.open(pin, :input, pull_mode: :pullup)
      Logger.debug("Opened GPIO #{inspect(input)}")
      Circuits.GPIO.set_interrupts(input, :both)
      input
    end
  end

  def listen_forever(platform, inputs \\ nil) do
    inputs = inputs || start(platform)

    receive do
      {:circuits_gpio, pin_number, _timestamp, 1} ->
        pin = Map.get(pins_by_number(platform), pin_number)
        Gamepad.InputTracker.release_buttons(pin.name)
        Logger.debug("release #{pin.name}")

      {:circuits_gpio, pin_number, _timestamp, 0} ->
        pin = Map.get(pins_by_number(platform), pin_number)
        Gamepad.InputTracker.hold_buttons(pin.name)
        Logger.debug("hold #{pin.name}")

      _ ->
        :ok
    end

    listen_forever(platform, inputs)
  end

  defp pins(:joybonnet) do
    [
      %{gpio_pin: 20, name: "minus"},
      %{gpio_pin: 23, name: "capture"},
      %{gpio_pin: 22, name: "home"},
      %{gpio_pin: 26, name: "plus"},
      %{gpio_pin: 16, name: "x"},
      %{gpio_pin: 13, name: "y"},
      %{gpio_pin: 6, name: "b"},
      %{gpio_pin: 12, name: "a"}
    ]
  end

  defp pins(:ammobox) do
    [
      %{gpio_pin: 26, name: "left"},
      %{gpio_pin: 19, name: "down"},
      %{gpio_pin: 6, name: "right"},
      %{gpio_pin: 5, name: "up"},
      %{gpio_pin: 11, name: "minus"},
      %{gpio_pin: 9, name: "home"},
      %{gpio_pin: 10, name: "plus"},
      %{gpio_pin: 22, name: "x"},
      %{gpio_pin: 27, name: "y"},
      %{gpio_pin: 17, name: "b"},
      %{gpio_pin: 4, name: "a"}
    ]
  end

  defp pins_by_number(platform) do
    for p <- pins(platform), into: %{} do
      {p.gpio_pin, p}
    end
  end
end
