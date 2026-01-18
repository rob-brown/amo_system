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
