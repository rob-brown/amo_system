defmodule AmiiboSerialization.FormatTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Format

  defp v3_tag do
    <<0x04>> <> :binary.copy(<<0>>, 0x5A) <> <<0x03>> <> :binary.copy(<<0>>, 2048 - 0x5C)
  end

  describe "of_tag/1" do
    test "detects a v3 tag from size and amiibo id format byte" do
      # Arrange
      tag = v3_tag()

      # Act
      result = Format.of_tag(tag)

      # Assert
      assert result == :v3
    end

    test "treats a 2048 byte binary with format byte 0x02 as v2" do
      # Arrange
      tag = binary_part(v3_tag(), 0, 0x5B) <> <<0x02>> <> :binary.copy(<<0>>, 2048 - 0x5C)

      # Act
      result = Format.of_tag(tag)

      # Assert
      assert result == :v2
    end

    test "treats a 540 byte binary as v2" do
      # Arrange
      tag = :binary.copy(<<0>>, 540)

      # Act
      result = Format.of_tag(tag)

      # Assert
      assert result == :v2
    end
  end

  describe "extract_tail/2 and split_tail/2" do
    test "v3 tail round trips reserved bytes and unmanaged data" do
      # Arrange
      tag = :binary.copy(<<7>>, 2048)

      # Act
      tail = Format.extract_tail(:v3, tag)
      {reserved, rest} = Format.split_tail(:v3, tail)

      # Assert
      assert byte_size(tail) == 2048 - 520
      assert byte_size(reserved) == 64
      assert byte_size(rest) == 2048 - 0x248
    end

    test "v2 tail is everything after the internal layout" do
      # Arrange
      tag = :binary.copy(<<7>>, 540)

      # Act
      tail = Format.extract_tail(:v2, tag)

      # Assert
      assert byte_size(tail) == 20
      assert Format.split_tail(:v2, tail) == {<<>>, tail}
    end
  end
end
