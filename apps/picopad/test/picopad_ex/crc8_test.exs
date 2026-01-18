defmodule Picopad.CRC8Test do
  use ExUnit.Case

  alias Picopad.CRC8

  describe "calculate/1" do
    test "empty binary returns 0" do
      assert CRC8.calculate(<<>>) == 0x00
    end

    test "single byte" do
      assert CRC8.calculate(<<0x01>>) == 0x07
    end

    test "known test vectors" do
      # Arrange
      test_cases = [
        {<<0x04, 0x00, 0x01>>, 0xAC},
        {<<0x05, 0x00, 0x01, 0x00>>, 0x5B},
        {<<0x04, 0x00, 0xF0>>, 0x75}
      ]

      # Act & Assert
      for {data, expected_crc} <- test_cases do
        assert CRC8.calculate(data) == expected_crc, "CRC mismatch for #{inspect(data)}"
      end
    end

    test "consistency" do
      # Arrange
      data = :crypto.strong_rand_bytes(50)

      # Act
      crc1 = CRC8.calculate(data)
      crc2 = CRC8.calculate(data)

      # Assert
      assert crc1 == crc2
    end
  end
end
