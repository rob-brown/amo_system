defmodule PicopadProxy.AmiiboFileTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo
  alias PicopadProxy.AmiiboFile

  @fixtures Path.expand("../../../../firmware/nordicpad/test/fixtures", __DIR__)

  defp v3_looking_tag do
    <<0x04>> <> :binary.copy(<<0>>, 0x5A) <> <<0x03>> <> :binary.copy(<<0>>, 2048 - 0x5C)
  end

  describe "parse/1" do
    test "rejects a file of any other size without crashing" do
      # Arrange
      sizes = [0, 1, 8, 9, 100, 539, 541, 1000, 2047, 2049]

      # Act
      results = for size <- sizes, do: AmiiboFile.parse(:binary.copy(<<0xAB>>, size))

      # Assert
      assert results == List.duplicate({:error, :unsupported_size}, length(sizes))
    end

    test "reports a v3 looking file that does not decrypt" do
      # Arrange
      binary = v3_looking_tag()

      # Act
      result = AmiiboFile.parse(binary)

      # Assert
      assert result == {:error, :decryption_failed}
    end

    test "accepts an already decrypted v2 dump" do
      # Arrange
      binary = :binary.copy(<<0>>, 540)

      # Act
      result = AmiiboFile.parse(binary)

      # Assert
      assert {:ok, %Amiibo{binary: ^binary}} = result
    end
  end

  describe "parse/1 with the console-verified dumps" do
    for {name, size, format} <- [{"nfc_v3_dump.bin", 2048, :v3}, {"nfc_v2_dump.bin", 540, :v2}] do
      path = Path.join(@fixtures, name)

      if File.exists?(path) do
        test "#{name} decrypts, reads as #{format} and encrypts back unchanged" do
          # Arrange
          binary = File.read!(unquote(path))

          # Act
          {:ok, amiibo} = AmiiboFile.parse(binary)
          encrypted = AmiiboFile.encrypt(amiibo.binary)

          # Assert
          assert byte_size(amiibo.binary) == unquote(size)
          assert Amiibo.format(amiibo) == unquote(format)
          assert encrypted == {:ok, binary}
        end
      end
    end
  end

  describe "encrypt/1" do
    test "reports a binary it cannot encrypt instead of raising" do
      # Arrange
      data = :binary.copy(<<0>>, 100)

      # Act
      result = AmiiboFile.encrypt(data)

      # Assert
      assert result == {:error, :encryption_failed}
    end
  end

  describe "message/1" do
    test "explains the file errors and defers the rest to the device errors" do
      # Arrange
      reasons = [:unsupported_size, :decryption_failed, :invalid_amiibo, :not_supported]

      # Act
      messages = Enum.map(reasons, &AmiiboFile.message/1)

      # Assert
      assert messages == [
               "Unsupported file size: expected a 540 byte (v2) or 2048 byte (v3) amiibo dump",
               "Could not decrypt the amiibo (wrong key or damaged file)",
               "Not a valid amiibo dump",
               "Not supported by this firmware"
             ]
    end
  end
end
