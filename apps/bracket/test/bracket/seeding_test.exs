defmodule Bracket.SeedingTest do
  use ExUnit.Case

  alias Bracket.Seeding

  describe "bracket_positions/1" do
    test "2-player bracket" do
      assert Seeding.bracket_positions(2) == [1, 2]
    end

    test "4-player bracket" do
      assert Seeding.bracket_positions(4) == [1, 4, 3, 2]
    end

    test "8-player bracket" do
      assert Seeding.bracket_positions(8) == [1, 8, 5, 4, 3, 6, 7, 2]
    end

    test "16-player bracket" do
      positions = Seeding.bracket_positions(16)

      # Top seed and bottom seed are at the extremes (never meet until finals)
      assert List.first(positions) == 1
      assert List.last(positions) == 2
    end

    test "every seed appears exactly once" do
      for size <- [2, 4, 8, 16] do
        positions = Seeding.bracket_positions(size)
        assert Enum.sort(positions) == Enum.to_list(1..size)
      end
    end

    test "seeds 1 and 2 are in opposite halves" do
      positions = Seeding.bracket_positions(8)
      idx_1 = Enum.find_index(positions, &(&1 == 1))
      idx_2 = Enum.find_index(positions, &(&1 == 2))
      half = div(length(positions), 2)

      assert idx_1 < half
      assert idx_2 >= half
    end
  end
end
