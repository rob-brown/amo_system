defmodule KAR.MachineTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo
  alias KAR.Fixtures
  alias KAR.Machine

  defp sram(code) do
    <<0::size(19 * 8)>> <> code <> <<0::size(39 * 8)>>
  end

  describe "read/1" do
    test "returns the UID and SRAM block of a v3 amiibo" do
      # Arrange
      uid = <<0x04, 9, 8, 7, 6, 5, 4>>
      amiibo = Fixtures.v3_amiibo(uid: uid, sram: sram("PB4W17"))

      # Act
      {:ok, machine} = Machine.read(amiibo)

      # Assert
      assert machine.uid == uid
      assert machine.sram == sram("PB4W17")
      assert Machine.code(machine) == "PB4W17"
    end

    test "refuses a v2 amiibo" do
      # Arrange
      amiibo = Amiibo.new(:binary.copy(<<0>>, 540))

      # Act
      result = Machine.read(amiibo)

      # Assert
      assert result == {:error, :not_v3}
    end
  end

  describe "write/2" do
    test "replaces the UID and SRAM together and touches nothing else" do
      # Arrange
      target = Fixtures.v3_amiibo()
      machine = %Machine{uid: <<0x04, 1, 1, 1, 1, 1, 1>>, sram: sram("PC6U55")}

      # Act
      {:ok, result} = Machine.write(target, machine)

      # Assert
      assert Machine.read(result) == {:ok, machine}

      assert binary_part(result.binary, 0, 468) == binary_part(target.binary, 0, 468)
      assert binary_part(result.binary, 475, 485) == binary_part(target.binary, 475, 485)
      assert binary_part(result.binary, 1024, 1024) == binary_part(target.binary, 1024, 1024)
    end

    test "refuses a v2 amiibo" do
      # Arrange
      amiibo = Amiibo.new(:binary.copy(<<0>>, 540))
      machine = %Machine{uid: <<0x04, 1, 1, 1, 1, 1, 1>>, sram: sram("PC6U55")}

      # Act
      result = Machine.write(amiibo, machine)

      # Assert
      assert result == {:error, :not_v3}
    end
  end
end
