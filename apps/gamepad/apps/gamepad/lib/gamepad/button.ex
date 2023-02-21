defmodule Gamepad.Button do
  require Logger

  @pins [
    # %{gpio_pin: 26, name: "left"},
    # %{gpio_pin: 19, name: "down"},
    # %{gpio_pin: 6, name: "right"},
    # %{gpio_pin: 5, name: "up"},
    %{gpio_pin: 20, name: "minus"},
    %{gpio_pin: 23, name: "capture"},
    %{gpio_pin: 22, name: "home"},
    %{gpio_pin: 26, name: "plus"},
    %{gpio_pin: 16, name: "x"},
    %{gpio_pin: 13, name: "y"},
    %{gpio_pin: 6, name: "b"},
    %{gpio_pin: 12, name: "a"}
  ]

  @pins_by_number Map.new(@pins, &{&1.gpio_pin, &1})

  def start() do
    for %{gpio_pin: pin} <- @pins do
      {:ok, input} = Circuits.GPIO.open(pin, :input, pull_mode: :pullup)
      Logger.debug("Opened GPIO #{inspect(input)}")
      Circuits.GPIO.set_interrupts(input, :both)
      input
    end
  end

  def listen_forever(inputs \\ start()) do
    receive do
      {:circuits_gpio, pin_number, _timestamp, 1} ->
        pin = Map.get(@pins_by_number, pin_number)
        Joycontrol.raw_command("release #{pin.name}")
        Logger.debug("release #{pin.name}")

      {:circuits_gpio, pin_number, _timestamp, 0} ->
        pin = Map.get(@pins_by_number, pin_number)
        Joycontrol.raw_command("hold #{pin.name}")
        Logger.debug("hold #{pin.name}")

      _ ->
        :ok
    end

    listen_forever(inputs)
  end
end
