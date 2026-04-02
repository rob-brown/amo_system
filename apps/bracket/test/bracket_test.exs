defmodule BracketTest do
  use ExUnit.Case

  alias Bracket

  describe "end-to-end single elimination" do
    test "4-player tournament plays to completion" do
      # Arrange
      tournament =
        Bracket.new("Weekend Smash", :single_elimination)
        |> Bracket.add_participant("Alice")
        |> Bracket.add_participant("Bob")
        |> Bracket.add_participant("Charlie")
        |> Bracket.add_participant("Dave")
        |> Bracket.start!()

      # Act — play all matches with p1 always winning
      tournament = play_all(tournament)

      # Assert
      assert Bracket.complete?(tournament)
      assert tournament.status == :complete
    end

    test "8-player tournament plays to completion" do
      tournament =
        ~w[A B C D E F G H]
        |> Enum.reduce(Bracket.new("Test", :single_elimination), fn name, t ->
          Bracket.add_participant(t, name)
        end)
        |> Bracket.start!()

      tournament = play_all(tournament)

      assert Bracket.complete?(tournament)
    end

    test "6-player tournament (bracket size 8) plays to completion with byes" do
      tournament =
        ~w[A B C D E F]
        |> Enum.reduce(Bracket.new("Test", :single_elimination), fn name, t ->
          Bracket.add_participant(t, name)
        end)
        |> Bracket.start!()

      tournament = play_all(tournament)

      assert Bracket.complete?(tournament)
    end

    test "add_participants/2 is equivalent to repeated add_participant/3" do
      # Arrange
      names = ~w[Alice Bob Charlie Dave]

      individual =
        names
        |> Enum.reduce(Bracket.new("Test", :single_elimination), fn name, t ->
          Bracket.add_participant(t, name)
        end)

      bulk = Bracket.add_participants(Bracket.new("Test", :single_elimination), names)

      # Assert
      assert length(individual.participants) == length(bulk.participants)

      Enum.zip(individual.participants, bulk.participants)
      |> Enum.each(fn {a, b} -> assert a.name == b.name end)
    end

    test "next_matches returns ready matches" do
      tournament =
        Bracket.new("Test", :single_elimination)
        |> Bracket.add_participant("Alice")
        |> Bracket.add_participant("Bob")
        |> Bracket.start!()

      matches = Bracket.next_matches(tournament)

      assert length(matches) == 1
      assert List.first(matches).status == :ready
    end

    test "TOML round-trip preserves complete tournament state" do
      # Arrange
      original =
        ~w[A B C D]
        |> Enum.reduce(Bracket.new("Roundtrip Test", :single_elimination), fn name, t ->
          Bracket.add_participant(t, name)
        end)
        |> Bracket.start!()
        |> play_all()

      # Act
      toml = Bracket.to_toml(original)
      {:ok, restored} = Bracket.from_toml(toml)

      # Assert
      assert Bracket.complete?(restored)
      assert map_size(restored.matches) == map_size(original.matches)
    end
  end

  describe "best_of_3 scoring" do
    test "match requires 2 set wins to complete" do
      # Arrange
      tournament =
        Bracket.new("Test", :single_elimination, config: [best_of: 3])
        |> Bracket.add_participant("Alice")
        |> Bracket.add_participant("Bob")
        |> Bracket.start!()

      [match_id] = List.first(tournament.rounds)
      score = Bracket.Score.new(3, 1)

      # Act — first set win doesn't complete
      {:ok, t1} = Bracket.report_score(tournament, match_id, score)
      assert t1.matches[match_id].status == :in_progress

      # Second set win completes
      score2 = Bracket.Score.add_set(score, 3, 2)
      {:ok, t2} = Bracket.report_score(t1, match_id, score2)
      assert t2.matches[match_id].status == :complete
    end
  end

  defp play_all(tournament) do
    ready = Bracket.next_matches(tournament)

    if ready == [] do
      tournament
    else
      tournament =
        Enum.reduce(ready, tournament, fn match, t ->
          case Bracket.report_score(t, match.id, 3, 0) do
            {:ok, t2} -> t2
            _ -> t
          end
        end)

      play_all(tournament)
    end
  end
end
