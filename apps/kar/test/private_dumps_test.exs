defmodule KAR.PrivateDumpsTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo
  alias KAR.Fixtures
  alias KAR.Machines

  @moduletag :private_dumps

  @scans %{
    "Dedede+TankStar" => {:king_dedede, :tank_star},
    "Kawasaki+HopStar" => {:kawasaki, :hop_star},
    "Kirby+WarpStar" => {:kirby, :warp_star},
    "MetaKnight+ShadowStar" => {:meta_knight, :shadow_star},
    "NoirDedede+Hydra" => {:noir_dedede, :hydra},
    "SwordKirby+Dragoon" => {:sword_kirby, :dragoon},
    "WaddleDee+WingStar" => {:waddle_dee, :wing_star}
  }

  describe "the full figure set" do
    test "each figure's SRAM is its default machine and its rider is known" do
      for {file, {rider, machine}} <- @scans do
        # Arrange
        amiibo = Fixtures.decrypted_scan(file)

        # Act
        machine_result = KAR.machine(amiibo)
        rider_result = KAR.rider(amiibo)

        # Assert
        assert {:ok, %{name: ^machine}} = machine_result, file
        assert rider_result == {:ok, %{name: rider, default_machine: machine}}, file
        assert KAR.default_machine(amiibo) == {:ok, machine}, file
      end
    end

    test "the hard-coded machines are the dumps' SRAM blocks" do
      for {file, {_rider, machine}} <- @scans do
        # Arrange
        expected = binary_part(Fixtures.scan(file), 0x3C0, 64)

        # Act
        result = Machines.sram(machine)

        # Assert
        assert result == {:ok, expected}, file
      end
    end

    test "the figures are unregistered" do
      for file <- Map.keys(@scans) do
        # Arrange
        amiibo = Fixtures.decrypted_scan(file)

        # Act
        result = KAR.registered?(amiibo)

        # Assert
        refute result, file
      end
    end

    test "decrypt then encrypt returns each original dump" do
      for file <- Map.keys(@scans) do
        # Arrange
        original = Fixtures.scan(file)
        amiibo = Fixtures.decrypted_scan(file)

        # Act
        result = Fixtures.encrypt!(amiibo)

        # Assert
        assert result == original, file
      end
    end
  end

  describe "registered figures" do
    test "are recognised as KAR amiibo" do
      for file <- ["kirby", "metaknight-registered", "dedede-registered"] do
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
    test "puts Tank Star on a registered Kirby and keeps its UID and payload" do
      # Arrange
      kirby = Fixtures.decrypted("kirby")
      kirby_dump = Fixtures.dump("kirby")
      tank_dump = Fixtures.scan("Dedede+TankStar")

      # Act
      {:ok, swapped} = KAR.set_machine(kirby, :tank_star)
      encrypted = Fixtures.encrypt!(swapped)
      {:ok, round_trip} = AmiiboSerialization.decrypt_binary(encrypted, Fixtures.key_path())

      # Assert
      assert binary_part(encrypted, 0, 8) == binary_part(kirby_dump, 0, 8)
      assert binary_part(encrypted, 0x3C0, 64) == binary_part(tank_dump, 0x3C0, 64)
      assert Fixtures.encrypt!(Amiibo.new(round_trip)) == encrypted
      assert Amiibo.nickname(swapped) == Amiibo.nickname(kirby)
      assert Amiibo.amiibo_id(swapped) == Amiibo.amiibo_id(kirby)
    end

    test "giving a figure its own machine reproduces the original dump" do
      for {file, {_rider, machine}} <- @scans do
        # Arrange
        original = Fixtures.scan(file)
        amiibo = Fixtures.decrypted_scan(file)

        # Act
        {:ok, same} = KAR.set_machine(amiibo, machine)

        # Assert
        assert Fixtures.encrypt!(same) == original, file
      end
    end
  end
end
