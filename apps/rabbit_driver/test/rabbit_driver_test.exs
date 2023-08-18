defmodule RabbitDriverTest do
  use ExUnit.Case
  doctest RabbitDriver

  test "greets the world" do
    assert RabbitDriver.hello() == :world
  end
end
