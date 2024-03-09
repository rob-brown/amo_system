defmodule HardwareTest do
  use ExUnit.Case
  doctest Hardware

  test "greets the world" do
    assert Hardware.hello() == :world
  end
end
