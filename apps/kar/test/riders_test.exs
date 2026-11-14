defmodule KAR.RidersTest do
  use ExUnit.Case, async: true

  alias AmiiboSerialization.Amiibo
  alias KAR.Fixtures

  defp with_id(id) do
    Fixtures.v3_amiibo() |> Amiibo.set_id(id)
  end

  describe "KAR.rider/1" do
    test "reads the rider and default machine from the amiibo id" do
      # Arrange
      amiibo = with_id(<<0x1F, 0x02, 0x01, 0x00, 0x04, 0xC8, 0x1E, 0x03>>)

      # Act
      result = KAR.rider(amiibo)

      # Assert
      assert result == {:ok, %{name: :noir_dedede, default_machine: :hydra}}
    end

    test "ignores the serial bytes of the id" do
      # Arrange
      amiibo = with_id(<<0x1F, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x1E, 0x03>>)

      # Act
      result = KAR.default_machine(amiibo)

      # Assert
      assert result == {:ok, :warp_star}
    end

    test "reports an id that is not a known rider" do
      # Arrange
      amiibo = with_id(<<0x99, 0x99, 0x99, 0x99, 0x04, 0xC4, 0x1E, 0x03>>)

      # Act
      result = KAR.rider(amiibo)

      # Assert
      assert result == {:error, :unknown_rider}
    end
  end

  describe "KAR.riders/0" do
    test "lists every rider" do
      # Arrange and Act
      names = KAR.riders()

      # Assert
      assert names == [
               :kawasaki,
               :king_dedede,
               :kirby,
               :meta_knight,
               :noir_dedede,
               :sword_kirby,
               :waddle_dee
             ]
    end
  end
end
