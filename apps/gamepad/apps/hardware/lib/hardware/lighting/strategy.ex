defmodule Gamepad.Lighting.Strategy do
  alias Gamepad.Lighting.LED

  defstruct []

  def blink(delay \\ 500, peak \\ 255) do
    fn leds ->
      for l <- leds do
        if l.brightness == 0 do
          %LED{l | brightness: peak}
        else
          %LED{l | brightness: 0}
        end
      end
      |> send_updates(delay)
    end
  end

  def pulse(delay \\ 1) do
    fn leds ->
      for l <- leds do
        direction = Map.get(l.extra, :direction, 1)
        brightness = l.brightness + direction
        direction = if brightness > 254 or brightness < 1, do: direction * -1, else: direction
        extra = Map.put(l.extra, :direction, direction)
        %LED{l | brightness: brightness, extra: extra}
      end
      |> send_updates(delay)
    end
  end

  def on(brightness \\ 128) do
    fn leds ->
      for l <- leds do
        %LED{l | brightness: brightness}
      end
      |> send_updates(5000)
    end
  end

  def off() do
    fn leds ->
      for l <- leds do
        %LED{l | brightness: 0}
      end
      |> send_updates(5000)
    end
  end

  defp send_updates(leds, delay) do
    for l <- leds do
      Pigpiox.Pwm.gpio_pwm(l.pin, l.brightness)
    end

    {leds, delay}
  end
end
