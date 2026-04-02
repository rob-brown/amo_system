defmodule Bracket.Format.SwissTest do
  use ExUnit.Case

  alias Bracket

  defp build_and_start(names, opts \\ []) do
    names
    |> Enum.reduce(Bracket.new("Test", :swiss, opts), fn name, t ->
      Bracket.add_participant(t, name)
    end)
    |> Bracket.start!()
  end

  describe "generate_matches/1" do
    test "first round has n/2 matches for even player count" do
      tournament = build_and_start(~w[A B C D E F G H])

      round1_ids = List.first(tournament.rounds)
      assert length(round1_ids) == 4
    end

    test "first round matches are all ready" do
      tournament = build_and_start(~w[A B C D])

      round1_ids = List.first(tournament.rounds)

      Enum.each(round1_ids, fn id ->
        assert tournament.matches[id].status == :ready
      end)
    end

    test "returns error with fewer than 2 participants" do
      tournament = Bracket.add_participant(Bracket.new("Test", :swiss), "Solo")
      assert {:error, :not_enough_participants} = Bracket.start(tournament)
    end
  end

  describe "generate_next_round/1" do
    test "generates subsequent rounds after completing current" do
      tournament = build_and_start(~w[A B C D])

      # Complete round 1
      tournament = play_current_round(tournament)
      assert length(tournament.rounds) == 1

      # Generate round 2
      {:ok, tournament} = Bracket.next_round(tournament)
      assert length(tournament.rounds) == 2

      round2_ids = List.last(tournament.rounds)
      assert length(round2_ids) == 2
    end

    test "no repeat matchups across rounds" do
      tournament = build_and_start(~w[A B C D E F])

      tournament = play_all_rounds(tournament)

      all_pairs =
        tournament.matches
        |> Map.values()
        |> Enum.map(fn m ->
          [m.p1_id, m.p2_id] |> Enum.sort() |> List.to_tuple()
        end)

      assert length(all_pairs) == length(Enum.uniq(all_pairs))
    end

    test "returns error when current round is incomplete" do
      tournament = build_and_start(~w[A B C D])

      assert {:error, :current_round_incomplete} = Bracket.next_round(tournament)
    end
  end

  describe "complete?/1" do
    test "not complete after first round" do
      tournament = build_and_start(~w[A B C D])
      tournament = play_current_round(tournament)

      refute Bracket.complete?(tournament)
    end

    test "complete after all rounds" do
      tournament = build_and_start(~w[A B C D])
      tournament = play_all_rounds(tournament)

      assert Bracket.complete?(tournament)
    end
  end

  describe "standings/1" do
    test "player with most wins ranks first" do
      tournament = build_and_start(~w[A B C D])
      tournament = play_all_rounds(tournament)

      standings = Bracket.standings(tournament)
      [first | _] = standings

      assert first.wins >= List.last(standings).wins
    end
  end

  describe "next_round/1 format restriction" do
    test "returns error for non-swiss format" do
      tournament =
        Bracket.new("Test", :single_elimination)
        |> Bracket.add_participant("A")
        |> Bracket.add_participant("B")
        |> Bracket.start!()

      assert {:error, {:not_applicable, :single_elimination}} = Bracket.next_round(tournament)
    end
  end

  defp play_current_round(tournament) do
    ready = Bracket.next_matches(tournament)

    Enum.reduce(ready, tournament, fn match, t ->
      case Bracket.report_score(t, match.id, 3, 0) do
        {:ok, t2} -> t2
        _ -> t
      end
    end)
  end

  defp play_all_rounds(tournament) do
    tournament = play_current_round(tournament)

    case Bracket.next_round(tournament) do
      {:ok, tournament} -> play_all_rounds(tournament)
      {:error, :tournament_complete} -> tournament
      {:error, :current_round_incomplete} -> tournament
      _ -> tournament
    end
  end
end
