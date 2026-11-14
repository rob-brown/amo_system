defmodule AmiiboTest do
  use ExUnit.Case
  alias AmiiboSerialization.Amiibo

  test "handle nickname with trailing garbage" do
    nickname =
      <<0x00, 0x43, 0x00, 0x65, 0x00, 0x63, 0x00, 0x69, 0x00, 0x6C, 0x00, 0x00, 0x00, 0x00, 0x00,
        0x0C, 0x11, 0x25, 0x7F, 0x78>>

    bin = <<0::integer-size(448), nickname::binary, 0::integer-size(3712)>>
    amiibo = Amiibo.new(bin)

    assert "Cecil" == Amiibo.nickname(amiibo)
  end

  describe "put_bytes/3" do
    test "replaces only the given range" do
      # Arrange
      amiibo = Amiibo.new(:binary.copy(<<1>>, 540))

      # Act
      result = Amiibo.put_bytes(amiibo, 10, <<9, 9, 9>>)

      # Assert
      assert result.binary ==
               :binary.copy(<<1>>, 10) <> <<9, 9, 9>> <> :binary.copy(<<1>>, 527)
    end

    test "rejects a range that runs past the end" do
      # Arrange
      amiibo = Amiibo.new(:binary.copy(<<1>>, 540))

      # Act and Assert
      assert_raise FunctionClauseError, fn -> Amiibo.put_bytes(amiibo, 539, <<9, 9>>) end
    end
  end
end
