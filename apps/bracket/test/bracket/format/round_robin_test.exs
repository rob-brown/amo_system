defmodule Bracket.Format.RoundRobinTest do
  use ExUnit.Case

  alias Bracket

  defp build_and_start(names) do
    names
    |> Enum.reduce(Bracket.new("Test", :round_robin), fn name, t ->
      Bracket.add_participant(t, name)
    end)
    |> Bracket.start!()
  end

  describe "generate_matches/1" do
    test "4 players: 6 total matches across 3 rounds" do
      tournament = build_and_start(~w[A B C D])

      # n*(n-1)/2 matches for round robin
      assert map_size(tournament.matches) == 6
      assert length(tournament.rounds) == 3
    end

    test "5 players: 10 matches across 5 rounds" do
      tournament = build_and_start(~w[A B C D E])

      assert map_size(tournament.matches) == 10
      assert length(tournament.rounds) == 5
    end

    test "every pair plays exactly once for 4 players" do
      tournament = build_and_start(~w[A B C D])

      participants = tournament.participants

      pairs =
        tournament.matches
        |> Map.values()
        |> Enum.map(fn m -> {m.p1_id, m.p2_id} end)
        |> MapSet.new()

      expected_count = div(length(participants) * (length(participants) - 1), 2)
      assert MapSet.size(pairs) == expected_count
    end

    test "every pair plays exactly once for 6 players" do
      tournament = build_and_start(~w[A B C D E F])

      pairs =
        tournament.matches
        |> Map.values()
        |> Enum.map(fn m ->
          [m.p1_id, m.p2_id] |> Enum.sort() |> List.to_tuple()
        end)

      assert length(pairs) == length(Enum.uniq(pairs))
    end

    test "all round 1 matches are ready" do
      tournament = build_and_start(~w[A B C D])

      round1_ids = List.first(tournament.rounds)

      Enum.each(round1_ids, fn id ->
        assert tournament.matches[id].status == :ready
      end)
    end

    test "returns error with fewer than 2 participants" do
      tournament = Bracket.add_participant(Bracket.new("Test", :round_robin), "Solo")
      assert {:error, :not_enough_participants} = Bracket.start(tournament)
    end
  end

  describe "complete?/1" do
    test "not complete before any matches" do
      tournament = build_and_start(~w[A B C])
      refute Bracket.complete?(tournament)
    end

    test "complete after all matches played" do
      tournament = build_and_start(~w[A B C D])
      tournament = play_all(tournament)
      assert Bracket.complete?(tournament)
    end
  end

  describe "standings/1" do
    test "undefeated player is ranked first" do
      # Arrange
      tournament = build_and_start(~w[A B C D])

      # Act — A wins all matches
      tournament = play_all_p1_wins(tournament)
      standings = Bracket.standings(tournament)

      # Assert
      first = List.first(standings)
      winner_p = Enum.find(tournament.participants, &(&1.name == "A"))
      assert first.participant_id == winner_p.id
      assert first.wins == 3
    end

    test "all players play same number of matches" do
      tournament = build_and_start(~w[A B C])
      tournament = play_all(tournament)
      standings = Bracket.standings(tournament)

      total_matches_per_player = Enum.map(standings, fn s -> s.wins + s.losses + s.draws end)
      assert Enum.all?(total_matches_per_player, &(&1 == 2))
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

  defp play_all_p1_wins(tournament) do
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

      play_all_p1_wins(tournament)
    end
  end
end
