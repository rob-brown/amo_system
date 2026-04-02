defmodule Bracket.ScoreTest do
  use ExUnit.Case

  alias Bracket.Score

  describe "new/0" do
    test "creates empty score" do
      # Act
      score = Score.new()

      # Assert
      assert score.sets == []
    end
  end

  describe "new/2" do
    test "creates score with single set" do
      # Act
      score = Score.new(3, 1)

      # Assert
      assert score.sets == [{3, 1}]
    end
  end

  describe "add_set/3" do
    test "appends sets in order" do
      # Arrange
      score = Score.new(3, 1)

      # Act
      result = Score.add_set(score, 2, 3)

      # Assert
      assert result.sets == [{3, 1}, {2, 3}]
    end
  end

  describe "winner/1" do
    test "returns :p1 when p1 wins more sets" do
      score = %Score{sets: [{3, 1}, {2, 3}, {3, 0}]}
      assert Score.winner(score) == :p1
    end

    test "returns :p2 when p2 wins more sets" do
      score = %Score{sets: [{1, 3}, {3, 2}, {0, 3}]}
      assert Score.winner(score) == :p2
    end

    test "returns :tie on equal set wins" do
      score = %Score{sets: [{3, 1}, {1, 3}]}
      assert Score.winner(score) == :tie
    end

    test "returns :p1 for single winning set" do
      score = Score.new(3, 1)
      assert Score.winner(score) == :p1
    end
  end

  describe "complete?/2" do
    test "returns true when p1 wins enough sets for best_of 3" do
      score = %Score{sets: [{3, 1}, {3, 2}]}
      assert Score.complete?(score, 3)
    end

    test "returns true when p2 wins enough sets for best_of 3" do
      score = %Score{sets: [{1, 3}, {2, 3}]}
      assert Score.complete?(score, 3)
    end

    test "returns false when neither player has won enough" do
      score = %Score{sets: [{3, 1}]}
      refute Score.complete?(score, 3)
    end

    test "is immediately complete for best_of 1" do
      score = Score.new(3, 1)
      assert Score.complete?(score, 1)
    end

    test "requires 3 wins for best_of 5" do
      two_wins = %Score{sets: [{3, 1}, {3, 2}]}
      three_wins = %Score{sets: [{3, 1}, {3, 2}, {3, 0}]}

      refute Score.complete?(two_wins, 5)
      assert Score.complete?(three_wins, 5)
    end
  end

  describe "from_csv/1 and to_csv/1" do
    test "round-trips single set" do
      csv = "3-1"
      assert Score.to_csv(Score.from_csv(csv)) == csv
    end

    test "round-trips multiple sets" do
      csv = "3-1,2-3,3-0"
      assert Score.to_csv(Score.from_csv(csv)) == csv
    end

    test "handles empty string" do
      assert Score.from_csv("").sets == []
      assert Score.to_csv(Score.new()) == ""
    end
  end
end
