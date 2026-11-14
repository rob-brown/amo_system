defmodule KAR.PrivateDumpsTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo
  alias KAR.Fixtures
  alias KAR.Machine

  @moduletag :private_dumps

  describe "machine/1" do
    test "reads each figure's own UID, SRAM and code" do
      # Arrange
      expected = %{
        "kirby" => "PB4W17",
        "metaknight-registered" => "PB5T42",
        "dedede-registered" => "PC6U55"
      }

      for {name, code} <- expected do
        # Act
        {:ok, machine} = name |> Fixtures.decrypted() |> KAR.machine()
        encrypted = Fixtures.dump(name)

        # Assert
        assert Machine.code(machine) == code, name
        assert machine.uid == binary_part(encrypted, 0, 7), name
        assert machine.sram == binary_part(encrypted, 0x3C0, 64), name
      end
    end
  end

  describe "registered?/1" do
    test "is true for every real KAR dump" do
      for name <- ["kirby", "metaknight-registered", "dedede-registered"] do
        # Arrange
        amiibo = Fixtures.decrypted(name)

        # Act
        result = KAR.registered?(amiibo)

        # Assert
        assert result, name
      end
    end
  end

  describe "set_machine/2" do
    test "moves Dedede's machine onto Kirby and survives encrypt and decrypt" do
      # Arrange
      kirby = Fixtures.decrypted("kirby")
      dedede = Fixtures.decrypted("dedede-registered")
      dedede_dump = Fixtures.dump("dedede-registered")

      # Act
      {:ok, swapped} = KAR.set_machine(kirby, dedede)
      encrypted = Fixtures.encrypt!(swapped)
      {:ok, round_trip} = AmiiboSerialization.decrypt_binary(encrypted, Fixtures.key_path())

      # Assert
      assert KAR.machine(swapped) == KAR.machine(dedede)
      assert Fixtures.encrypt!(Amiibo.new(round_trip)) == encrypted
      assert KAR.machine(Amiibo.new(round_trip)) == KAR.machine(dedede)
      assert binary_part(encrypted, 0, 7) == binary_part(dedede_dump, 0, 7)
      assert binary_part(encrypted, 0x3C0, 64) == binary_part(dedede_dump, 0x3C0, 64)
      assert Amiibo.nickname(swapped) == Amiibo.nickname(kirby)
      assert Amiibo.amiibo_id(swapped) == Amiibo.amiibo_id(kirby)
    end

    test "setting a figure's own machine reproduces the original dump" do
      # Arrange
      original = Fixtures.dump("metaknight-registered")
      amiibo = Fixtures.decrypted("metaknight-registered")

      # Act
      {:ok, same} = KAR.set_machine(amiibo, amiibo)

      # Assert
      assert Fixtures.encrypt!(same) == original
    end
  end
end
