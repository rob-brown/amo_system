defmodule KAR.MachineTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo
  alias KAR.Fixtures
  alias KAR.Machine
  alias KAR.Machines

  defp sram(code) do
    <<0::size(19 * 8)>> <> code <> <<0::size(39 * 8)>>
  end

  defp v2_amiibo, do: Amiibo.new(:binary.copy(<<0>>, 540))

  describe "read/1" do
    test "returns the SRAM block and its code" do
      # Arrange
      amiibo = Fixtures.v3_amiibo(sram: sram("PB4W17"))

      # Act
      {:ok, machine} = Machine.read(amiibo)

      # Assert
      assert machine.sram == sram("PB4W17")
      assert machine.code == "PB4W17"
      assert machine.name == nil
    end

    test "names a machine whose SRAM is a known block" do
      # Arrange
      {:ok, tank_sram} = Machines.sram(:tank_star)
      amiibo = Fixtures.v3_amiibo(sram: tank_sram)

      # Act
      {:ok, machine} = Machine.read(amiibo)

      # Assert
      assert machine.name == :tank_star
      assert machine.code == "PC6U55"
    end

    test "refuses a v2 amiibo" do
      # Arrange
      amiibo = v2_amiibo()

      # Act
      result = Machine.read(amiibo)

      # Assert
      assert result == {:error, :not_v3}
    end
  end

  describe "KAR.set_machine/2" do
    test "writes a named machine's SRAM and touches nothing else" do
      # Arrange
      target = Fixtures.v3_amiibo()
      {:ok, expected} = Machines.sram(:shadow_star)

      # Act
      {:ok, result} = KAR.set_machine(target, :shadow_star)

      # Assert
      assert binary_part(result.binary, 960, 64) == expected
      assert binary_part(result.binary, 0, 960) == binary_part(target.binary, 0, 960)
      assert binary_part(result.binary, 1024, 1024) == binary_part(target.binary, 1024, 1024)
    end

    test "keeps the amiibo's own UID" do
      # Arrange
      target = Fixtures.v3_amiibo(uid: <<0x04, 9, 8, 7, 6, 5, 4>>)

      # Act
      {:ok, result} = KAR.set_machine(target, :tank_star)

      # Assert
      assert Amiibo.serial_number(result) == <<0x04, 9, 8, 7, 6, 5, 4>>
    end

    test "accepts raw SRAM bytes" do
      # Arrange
      target = Fixtures.v3_amiibo()
      raw = sram("PX1Y22")

      # Act
      {:ok, result} = KAR.set_machine(target, raw)

      # Assert
      assert KAR.machine(result) == {:ok, Machine.new(raw)}
    end

    test "accepts another amiibo's machine and a machine struct" do
      # Arrange
      target = Fixtures.v3_amiibo()
      source = Fixtures.v3_amiibo(sram: sram("PA2B33"))
      {:ok, machine} = KAR.machine(source)

      # Act
      {:ok, from_amiibo} = KAR.set_machine(target, source)
      {:ok, from_struct} = KAR.set_machine(target, machine)

      # Assert
      assert from_amiibo == from_struct
      assert KAR.machine(from_amiibo) == {:ok, machine}
    end

    test "rejects an unknown machine name" do
      # Arrange
      target = Fixtures.v3_amiibo()

      # Act
      result = KAR.set_machine(target, :bogus_star)

      # Assert
      assert result == {:error, :unknown_machine}
    end

    test "rejects SRAM of the wrong size" do
      # Arrange
      target = Fixtures.v3_amiibo()

      # Act
      result = KAR.set_machine(target, <<1, 2, 3>>)

      # Assert
      assert result == {:error, :invalid_machine}
    end

    test "refuses a v2 amiibo" do
      # Arrange
      target = v2_amiibo()

      # Act
      result = KAR.set_machine(target, :tank_star)

      # Assert
      assert result == {:error, :not_v3}
    end
  end

  describe "KAR.machines/0" do
    test "lists the hard-coded machines" do
      # Arrange and Act
      names = KAR.machines()

      # Assert
      assert names == [:shadow_star, :tank_star, :warp_star]
    end
  end
end
