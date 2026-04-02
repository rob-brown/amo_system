defmodule Bracket.Format.SingleEliminationTest do
  use ExUnit.Case

  alias Bracket

  defp build_and_start(names, opts \\ []) do
    names
    |> Enum.reduce(Bracket.new("Test", :single_elimination, opts), fn name, t ->
      Bracket.add_participant(t, name)
    end)
    |> Bracket.start!()
  end

  describe "generate_matches/1" do
    test "2 players produces 1 match" do
      tournament = build_and_start(["Alice", "Bob"])

      assert map_size(tournament.matches) == 1
      assert length(List.flatten(tournament.rounds)) == 1
    end

    test "4 players produces 3 matches across 2 rounds" do
      tournament = build_and_start(["A", "B", "C", "D"])

      assert map_size(tournament.matches) == 3
      assert length(tournament.rounds) == 2
      assert Enum.map(tournament.rounds, &length/1) == [2, 1]
    end

    test "8 players produces 7 matches across 3 rounds" do
      tournament = build_and_start(~w[A B C D E F G H])

      assert map_size(tournament.matches) == 7
      assert length(tournament.rounds) == 3
    end

    test "5 players produces bracket of size 8 with 3 byes" do
      tournament = build_and_start(~w[A B C D E])

      byes = tournament.matches |> Map.values() |> Enum.count(&(&1.status == :bye))
      assert byes == 3
    end

    test "bye winners advance to round 2 automatically" do
      tournament = build_and_start(~w[A B C])

      round2_matches =
        tournament.matches
        |> Map.values()
        |> Enum.filter(&(&1.round == 2))

      assert Enum.any?(round2_matches, fn m -> m.p1_id != nil or m.p2_id != nil end)
    end

    test "returns error with fewer than 2 participants" do
      tournament = Bracket.add_participant(Bracket.new("Test", :single_elimination), "Solo")

      assert {:error, :not_enough_participants} = Bracket.start(tournament)
    end

    test "round 1 matches are all ready" do
      tournament = build_and_start(~w[A B C D])

      round1_ids = List.first(tournament.rounds)

      Enum.each(round1_ids, fn id ->
        match = tournament.matches[id]
        assert match.status in [:ready, :bye]
      end)
    end

    test "later round matches start as pending" do
      tournament = build_and_start(~w[A B C D])

      round2_ids = Enum.at(tournament.rounds, 1)

      Enum.each(round2_ids, fn id ->
        assert tournament.matches[id].status == :pending
      end)
    end

    test "winner_feeds chains are correct for 4 players" do
      tournament = build_and_start(~w[A B C D])

      round1_ids = List.first(tournament.rounds)
      [r2_id] = Enum.at(tournament.rounds, 1)

      Enum.each(round1_ids, fn id ->
        match = tournament.matches[id]
        assert match.winner_feeds != nil
        {target_id, _slot} = match.winner_feeds
        assert target_id == r2_id
      end)
    end
  end

  describe "match progression" do
    test "reporting score marks match complete and advances winner" do
      # Arrange
      tournament = build_and_start(~w[Alice Bob Charlie Dave])
      [match_id | _] = List.first(tournament.rounds)
      match = tournament.matches[match_id]
      {next_match_id, slot} = match.winner_feeds

      # Act
      {:ok, tournament} = Bracket.report_score(tournament, match_id, 3, 1)

      # Assert
      assert tournament.matches[match_id].status == :complete
      winner_id = tournament.matches[match_id].winner_id
      next_match = tournament.matches[next_match_id]

      slot_value = if slot == :p1, do: next_match.p1_id, else: next_match.p2_id
      assert slot_value == winner_id
    end

    test "completing all round 1 matches makes round 2 matches ready" do
      # Arrange
      tournament = build_and_start(~w[A B C D])
      round1_ids = List.first(tournament.rounds)

      # Act
      tournament =
        Enum.reduce(round1_ids, tournament, fn id, t ->
          {:ok, t} = Bracket.report_score(t, id, 3, 0)
          t
        end)

      # Assert
      round2_ids = Enum.at(tournament.rounds, 1)

      Enum.each(round2_ids, fn id ->
        assert tournament.matches[id].status == :ready
      end)
    end

    test "tournament completes after finals" do
      # Arrange
      tournament = build_and_start(~w[A B C D])

      # Act
      tournament =
        Enum.reduce(tournament.rounds, tournament, fn round_ids, t ->
          Enum.reduce(round_ids, t, fn id, t2 ->
            match = t2.matches[id]

            if match.status in [:ready, :in_progress] do
              {:ok, t3} = Bracket.report_score(t2, id, 3, 0)
              t3
            else
              t2
            end
          end)
        end)

      # Assert
      assert Bracket.complete?(tournament)
    end

    test "cannot report score for pending match" do
      # Arrange
      tournament = build_and_start(~w[A B C D])
      [r2_id] = Enum.at(tournament.rounds, 1)

      # Act
      result = Bracket.report_score(tournament, r2_id, 3, 0)

      # Assert
      assert {:error, {:match_not_ready, :pending}} = result
    end

    test "returns error for non-existent match" do
      tournament = build_and_start(~w[A B])

      assert {:error, :not_found} = Bracket.report_score(tournament, "fake_id", 3, 0)
    end
  end

  describe "standings/1" do
    test "winner has most wins" do
      # Arrange
      tournament = build_and_start(~w[A B])
      [match_id] = List.first(tournament.rounds)

      # Act
      {:ok, tournament} = Bracket.report_score(tournament, match_id, 3, 0)
      standings = Bracket.standings(tournament)

      # Assert
      [first | _] = standings
      winner_id = tournament.matches[match_id].winner_id
      assert first.participant_id == winner_id
      assert first.wins == 1
      assert first.losses == 0
    end
  end

  describe "complete?/1" do
    test "not complete before any matches" do
      tournament = build_and_start(~w[A B])
      refute Bracket.complete?(tournament)
    end

    test "complete after final match" do
      tournament = build_and_start(~w[A B])
      [match_id] = List.first(tournament.rounds)
      {:ok, tournament} = Bracket.report_score(tournament, match_id, 3, 0)

      assert Bracket.complete?(tournament)
    end
  end
end
