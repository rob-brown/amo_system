defmodule KAR.PrivateDumpsTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo
  alias KAR.Fixtures
  alias KAR.Machines

  @moduletag :private_dumps

  @machines %{
    "kirby" => {:warp_star, "PB4W17"},
    "metaknight-registered" => {:shadow_star, "PB5T42"},
    "dedede-registered" => {:tank_star, "PC6U55"}
  }

  describe "machine/1" do
    test "names each figure's own machine and reads its code" do
      for {file, {name, code}} <- @machines do
        # Arrange
        amiibo = Fixtures.decrypted(file)

        # Act
        {:ok, machine} = KAR.machine(amiibo)

        # Assert
        assert machine.name == name, file
        assert machine.code == code, file
        assert machine.sram == binary_part(Fixtures.dump(file), 0x3C0, 64), file
      end
    end

    test "hard-coded machines match the dump SRAM blocks" do
      for {file, {name, _code}} <- @machines do
        # Arrange
        expected = binary_part(Fixtures.dump(file), 0x3C0, 64)

        # Act
        result = Machines.sram(name)

        # Assert
        assert result == {:ok, expected}, file
      end
    end
  end

  describe "registered?/1" do
    test "is true for every real KAR dump" do
      for file <- Map.keys(@machines) do
        # Arrange
        amiibo = Fixtures.decrypted(file)

        # Act
        result = KAR.registered?(amiibo)

        # Assert
        assert result, file
      end
    end
  end

  describe "set_machine/2" do
    test "puts Tank Star on Kirby, keeps Kirby's UID and survives encrypt and decrypt" do
      # Arrange
      kirby = Fixtures.decrypted("kirby")
      kirby_dump = Fixtures.dump("kirby")
      dedede_dump = Fixtures.dump("dedede-registered")

      # Act
      {:ok, swapped} = KAR.set_machine(kirby, :tank_star)
      encrypted = Fixtures.encrypt!(swapped)
      {:ok, round_trip} = AmiiboSerialization.decrypt_binary(encrypted, Fixtures.key_path())

      # Assert
      assert binary_part(encrypted, 0, 8) == binary_part(kirby_dump, 0, 8)
      assert binary_part(encrypted, 0x3C0, 64) == binary_part(dedede_dump, 0x3C0, 64)
      assert Fixtures.encrypt!(Amiibo.new(round_trip)) == encrypted
      assert KAR.machine(Amiibo.new(round_trip)) == KAR.machine(swapped)
      assert Amiibo.nickname(swapped) == Amiibo.nickname(kirby)
      assert Amiibo.amiibo_id(swapped) == Amiibo.amiibo_id(kirby)
    end

    test "giving a figure its own machine reproduces the original dump" do
      for {file, {name, _code}} <- @machines do
        # Arrange
        original = Fixtures.dump(file)
        amiibo = Fixtures.decrypted(file)

        # Act
        {:ok, same} = KAR.set_machine(amiibo, name)

        # Assert
        assert Fixtures.encrypt!(same) == original, file
      end
    end
  end
end
