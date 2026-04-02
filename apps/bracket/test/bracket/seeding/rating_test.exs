defmodule Bracket.Seeding.RatingTest do
  use ExUnit.Case

  alias Bracket
  alias Bracket.Seeding.Rating

  describe "by/1" do
    test "seeds players in descending order of rating" do
      # Arrange
      tournament =
        Bracket.new("Test", :single_elimination)
        |> Bracket.add_participant("Low", metadata: %{score: 100})
        |> Bracket.add_participant("High", metadata: %{score: 900})
        |> Bracket.add_participant("Mid", metadata: %{score: 500})

      strategy = Rating.by(fn p -> p.metadata[:score] end)

      # Act
      {:ok, tournament} = Bracket.start(tournament, strategy)

      # Assert
      participants_by_id = Map.new(tournament.participants, &{&1.id, &1})
      seeded = Enum.map(tournament.seeding, &participants_by_id[&1])

      assert Enum.at(seeded, 0).name == "High"
      assert Enum.at(seeded, 1).name == "Mid"
      assert Enum.at(seeded, 2).name == "Low"
    end
  end

  describe "by_trueskill/1" do
    test "seeds by mu - 3*sigma conservative estimate" do
      # Arrange — two players with same mu but different sigma
      # Lower sigma = more confident = higher conservative estimate
      tournament =
        Bracket.new("Test", :single_elimination)
        |> Bracket.add_participant("Certain", metadata: %{rating: {25.0, 1.0}})
        |> Bracket.add_participant("Uncertain", metadata: %{rating: {25.0, 8.33}})

      strategy = Rating.by_trueskill()

      # Act
      {:ok, tournament} = Bracket.start(tournament, strategy)

      # Assert — Certain (25 - 3) = 22 > Uncertain (25 - 24.99) ≈ 0.01
      participants_by_id = Map.new(tournament.participants, &{&1.id, &1})
      seed1_name = participants_by_id[Enum.at(tournament.seeding, 0)].name

      assert seed1_name == "Certain"
    end

    test "handles missing rating key gracefully" do
      tournament =
        Bracket.new("Test", :single_elimination)
        |> Bracket.add_participant("NoRating")
        |> Bracket.add_participant("HasRating", metadata: %{rating: {25.0, 8.33}})

      strategy = Rating.by_trueskill()

      # Should not raise
      assert {:ok, _} = Bracket.start(tournament, strategy)
    end

    test "supports custom metadata key" do
      tournament =
        Bracket.new("Test", :single_elimination)
        |> Bracket.add_participant("A", metadata: %{ts: {30.0, 5.0}})
        |> Bracket.add_participant("B", metadata: %{ts: {20.0, 2.0}})

      strategy = Rating.by_trueskill(:ts)

      {:ok, tournament} = Bracket.start(tournament, strategy)
      participants_by_id = Map.new(tournament.participants, &{&1.id, &1})
      seed1_name = participants_by_id[Enum.at(tournament.seeding, 0)].name

      # A: 30 - 15 = 15, B: 20 - 6 = 14 → A ranks higher
      assert seed1_name == "A"
    end
  end
end
