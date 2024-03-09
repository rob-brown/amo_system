defmodule ProxyTest do
  use ExUnit.Case
  doctest Proxy

  test "greets the world" do
    assert Proxy.hello() == :world
  end
end
