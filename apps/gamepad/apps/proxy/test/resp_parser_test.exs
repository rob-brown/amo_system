defmodule RespParserTest do
  use ExUnit.Case

  alias Proxy.RespParser

  test "parse int" do
    assert {42, ""} = RespParser.parse(":42\n")
  end

  test "parse simple string" do
    assert {"hello", ""} = RespParser.parse("+hello\n")
  end

  test "parse simple error" do
    assert {{:error, "error"}, ""} = RespParser.parse("-error\n")
  end

  test "parse bulk string" do
    assert {"hello", ""} = RespParser.parse("$5\nhello\n") 
  end

  test "parse list" do
    string = """
    *3
    $6
    answer
    +is
    :42
    """
    assert {result, ""} = RespParser.parse(string)
    assert ["answer", "is", 42] = result
  end

  test "parse push" do
    string = """
    >3
    :0
    :42
    :1
    """
    assert {result, ""} = RespParser.parse(string) 
    assert {:push, [0, 42, 1]} = result
  end

  test "parse map" do
    string = """
    %2
    $6
    answer
    :42
    +hello
    $5
    world
    """
    assert {result, ""} = RespParser.parse(string) 
    assert %{"answer" => 42, "hello" => "world"} = result
  end
end
