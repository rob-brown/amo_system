defmodule Gamepad.Lighting.LED do
  defstruct [:pin, :brightness, :extra]

  def new(pin, brightness \\ 0, extra \\ %{}) do
    %__MODULE__{pin: pin, brightness: brightness, extra: extra}
  end
end
