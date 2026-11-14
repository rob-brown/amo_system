defmodule AmiiboSerialization.PrivateDumpsTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo

  @moduletag :private_dumps

  @v3_dumps ["kirby.bin", "metaknight-registered.bin", "dedede-registered.bin"]

  defp key_path, do: System.fetch_env!("AMIIBO_KEY_PATH")

  defp v3_dump(name) do
    "AMIIBO_V3_DUMP_DIR" |> System.fetch_env!() |> Path.join(name) |> File.read!()
  end

  defp v2_dump, do: "AMIIBO_V2_DUMP" |> System.fetch_env!() |> File.read!()

  defp decrypt!(binary) do
    {:ok, decrypted} = AmiiboSerialization.decrypt_binary(binary, key_path())
    decrypted
  end

  defp encrypt!(binary) do
    {:ok, encrypted} = AmiiboSerialization.encrypt_binary(binary, key_path())
    encrypted
  end

  describe "encrypted?/1" do
    test "recognises encrypted and decrypted v3 dumps" do
      for name <- @v3_dumps do
        # Arrange
        encrypted = v3_dump(name)
        decrypted = decrypt!(encrypted)

        # Act
        results =
          {AmiiboSerialization.encrypted?(encrypted), AmiiboSerialization.encrypted?(decrypted)}

        # Assert
        assert results == {true, false}, name
      end
    end

    test "recognises encrypted and decrypted v2 dumps" do
      # Arrange
      encrypted = v2_dump()
      decrypted = decrypt!(encrypted)

      # Act
      results =
        {AmiiboSerialization.encrypted?(encrypted), AmiiboSerialization.encrypted?(decrypted)}

      # Assert
      assert results == {true, false}
    end
  end

  describe "decrypt_binary/2" do
    test "v3 dumps decrypt to 2048 bytes with valid hashes" do
      for name <- @v3_dumps do
        # Arrange
        encrypted = v3_dump(name)

        # Act
        result = AmiiboSerialization.decrypt_binary(encrypted, key_path())

        # Assert
        assert {:ok, decrypted} = result, name
        assert byte_size(decrypted) == 2048
      end
    end

    test "v2 dump decrypts to 540 bytes" do
      # Arrange
      encrypted = v2_dump()

      # Act
      decrypted = decrypt!(encrypted)

      # Assert
      assert byte_size(decrypted) == 540
    end
  end

  describe "encrypt_binary/2" do
    test "decrypt then encrypt returns the original v3 bytes" do
      for name <- @v3_dumps do
        # Arrange
        original = v3_dump(name)

        # Act
        result = original |> decrypt!() |> encrypt!()

        # Assert
        assert result == original, name
      end
    end

    test "decrypt then encrypt returns the original v2 bytes" do
      # Arrange
      original = v2_dump()

      # Act
      result = original |> decrypt!() |> encrypt!()

      # Assert
      assert result == original
    end

    test "editing a v3 nickname leaves the unmanaged regions untouched" do
      # Arrange
      original = v3_dump("metaknight-registered.bin")
      amiibo = original |> decrypt!() |> Amiibo.new()

      # Act
      edited = amiibo |> Amiibo.rename("Renamed") |> Map.fetch!(:binary) |> encrypt!()

      # Assert
      assert byte_size(edited) == 2048
      assert binary_part(edited, 0x080, 64) == binary_part(original, 0x080, 64)

      assert binary_part(edited, 0x248, 2048 - 0x248) ==
               binary_part(original, 0x248, 2048 - 0x248)

      assert edited != original
      assert edited |> decrypt!() |> Amiibo.new() |> Amiibo.nickname() == "Renamed"
    end
  end

  describe "Amiibo on decrypted v3" do
    test "reads registered nicknames" do
      # Arrange
      names = %{"metaknight-registered.bin" => "Ammoknight", "dedede-registered.bin" => "D3"}

      for {name, nickname} <- names do
        # Act
        amiibo = name |> v3_dump() |> decrypt!() |> Amiibo.new()

        # Assert
        assert Amiibo.nickname(amiibo) == nickname
        assert Amiibo.format(amiibo) == :v3
        assert binary_part(Amiibo.amiibo_id(amiibo), 7, 1) == <<3>>
      end
    end

    test "serial_number returns the 7 byte UID found at the start of the dump" do
      # Arrange
      encrypted = v3_dump("kirby.bin")
      amiibo = encrypted |> decrypt!() |> Amiibo.new()

      # Act
      serial = Amiibo.serial_number(amiibo)

      # Assert
      assert serial == binary_part(encrypted, 0, 7)
    end

    test "shuffle_serial produces a v3 binary that still encrypts and decrypts" do
      # Arrange
      amiibo = "kirby.bin" |> v3_dump() |> decrypt!() |> Amiibo.new()

      # Act
      shuffled = Amiibo.shuffle_serial(amiibo)
      reencrypted = encrypt!(shuffled.binary)

      # Assert
      assert Amiibo.serial_number(shuffled) != Amiibo.serial_number(amiibo)
      assert binary_part(reencrypted, 0, 7) == Amiibo.serial_number(shuffled)
      assert reencrypted |> decrypt!() |> encrypt!() == reencrypted

      assert reencrypted |> decrypt!() |> Amiibo.new() |> Amiibo.nickname() ==
               Amiibo.nickname(amiibo)
    end
  end
end
