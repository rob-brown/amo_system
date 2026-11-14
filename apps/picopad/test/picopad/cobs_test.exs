defmodule Picopad.COBSTest do
  use ExUnit.Case

  alias Picopad.COBS

  describe "encode/1" do
    test "empty binary" do
      assert COBS.encode(<<>>) == <<>>
    end

    test "single non-zero byte" do
      assert COBS.encode(<<0x42>>) == <<0x02, 0x42>>
    end

    test "single zero byte" do
      assert COBS.encode(<<0x00>>) == <<0x01, 0x01>>
    end

    test "multiple non-zero bytes" do
      assert COBS.encode(<<0x01, 0x02, 0x03>>) == <<0x04, 0x01, 0x02, 0x03>>
    end

    test "zero in the middle" do
      assert COBS.encode(<<0x01, 0x00, 0x02>>) == <<0x02, 0x01, 0x02, 0x02>>
    end

    test "multiple zeros" do
      assert COBS.encode(<<0x00, 0x00>>) == <<0x01, 0x01, 0x01>>
    end

    test "ends with zero" do
      assert COBS.encode(<<0x01, 0x02, 0x00>>) == <<0x03, 0x01, 0x02, 0x01>>
    end
  end

  describe "decode/1" do
    test "empty binary" do
      assert COBS.decode(<<>>) == {:ok, <<>>}
    end

    test "single non-zero byte" do
      assert COBS.decode(<<0x02, 0x42>>) == {:ok, <<0x42>>}
    end

    test "single zero byte" do
      assert COBS.decode(<<0x01, 0x01>>) == {:ok, <<0x00>>}
    end

    test "multiple non-zero bytes" do
      assert COBS.decode(<<0x04, 0x01, 0x02, 0x03>>) == {:ok, <<0x01, 0x02, 0x03>>}
    end

    test "zero in the middle" do
      assert COBS.decode(<<0x02, 0x01, 0x02, 0x02>>) == {:ok, <<0x01, 0x00, 0x02>>}
    end

    test "code byte of zero is invalid" do
      assert COBS.decode(<<0x00, 0x01>>) == {:error, :invalid_cobs}
    end

    test "invalid: incomplete data" do
      assert COBS.decode(<<0x05, 0x01, 0x02>>) == {:error, :incomplete}
    end
  end

  describe "runs without a zero byte" do
    test "a full block of 254 bytes is introduced by the code 0xFF" do
      # Arrange
      data = :binary.copy(<<0x11>>, 254)

      # Act
      encoded = COBS.encode(data)

      # Assert
      assert encoded == <<0xFF>> <> data
    end

    test "one byte more than a full block starts a second block" do
      # Arrange
      data = :binary.copy(<<0x11>>, 255)

      # Act
      encoded = COBS.encode(data)

      # Assert
      assert encoded == <<0xFF>> <> :binary.copy(<<0x11>>, 254) <> <<0x02, 0x11>>
    end

    test "lengths around the block boundary roundtrip" do
      # Arrange
      lengths = [252, 253, 254, 255, 256, 507, 508, 509, 1000]

      # Act
      results =
        for length <- lengths do
          data = :binary.copy(<<0x42>>, length)
          COBS.decode(COBS.encode(data))
        end

      # Assert
      assert results == for(length <- lengths, do: {:ok, :binary.copy(<<0x42>>, length)})
    end
  end

  describe "roundtrip" do
    test "various patterns" do
      patterns = [
        <<>>,
        <<0x00>>,
        <<0x01>>,
        <<0x00, 0x00>>,
        <<0x01, 0x02, 0x03>>,
        <<0x01, 0x00, 0x02>>,
        <<0x00, 0x01, 0x00, 0x02, 0x00>>,
        :crypto.strong_rand_bytes(100),
        :crypto.strong_rand_bytes(300)
      ]

      for pattern <- patterns do
        encoded = COBS.encode(pattern)
        assert {:ok, decoded} = COBS.decode(encoded)
        assert decoded == pattern, "Roundtrip failed for pattern: #{inspect(pattern)}"
      end
    end
  end
end
