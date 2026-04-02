defmodule Bracket.Format.Swiss do
  @moduledoc false

  @behaviour Bracket.Format

  alias Bracket.{Match, Score, Standings, Tournament}

  @impl true
  def generate_matches(%Tournament{} = tournament) do
    n = length(tournament.participants)

    if n < 2 do
      {:error, :not_enough_participants}
    else
      case generate_round(tournament, 1) do
        {:ok, tournament} -> {:ok, tournament}
        error -> error
      end
    end
  end

  @doc """
  Generates the next Swiss round after all matches in the current round are complete.
  Called externally after each round finishes.
  """
  @spec generate_next_round(Tournament.t()) :: {:ok, Tournament.t()} | {:error, term()}
  def generate_next_round(%Tournament{} = tournament) do
    current_round = current_round_number(tournament)

    if current_round_complete?(tournament, current_round) do
      max_rounds = max_rounds(tournament)

      if current_round >= max_rounds do
        {:error, :tournament_complete}
      else
        generate_round(tournament, current_round + 1)
      end
    else
      {:error, :current_round_incomplete}
    end
  end

  defp generate_round(%Tournament{} = tournament, round_number) do
    standings = compute_standings_for_pairing(tournament)
    played = already_played_pairs(tournament)

    case pair_monrad(standings, played) do
      {:ok, pairs} ->
        matches =
          pairs
          |> Enum.with_index()
          |> Enum.map(fn {{p1_id, p2_id}, pos} ->
            Match.new(
              id: match_id(round_number, pos),
              round: round_number,
              position: pos,
              p1_id: p1_id,
              p2_id: p2_id,
              status: :ready
            )
          end)

        round_ids = Enum.map(matches, & &1.id)
        matches_map = Map.merge(tournament.matches, Map.new(matches, &{&1.id, &1}))
        rounds = tournament.rounds ++ [round_ids]

        tournament =
          %{tournament | matches: matches_map, rounds: rounds}
          |> Tournament.touch()

        {:ok, tournament}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp pair_monrad(standings, played) do
    ordered = Enum.map(standings, & &1.participant_id)
    do_pair(ordered, played, [])
  end

  defp do_pair([], _played, pairs), do: {:ok, Enum.reverse(pairs)}

  defp do_pair([p1 | rest], played, pairs) do
    case find_opponent(p1, rest, played) do
      {:ok, p2, remaining} ->
        do_pair(remaining, played, [{p1, p2} | pairs])

      :error ->
        {:error, {:no_valid_pairing, p1}}
    end
  end

  defp find_opponent(_p1, [], _played), do: :error

  defp find_opponent(p1, [p2 | rest], played) do
    if {p1, p2} in played or {p2, p1} in played do
      case find_opponent(p1, rest, played) do
        {:ok, found, remaining} -> {:ok, found, [p2 | remaining]}
        :error -> :error
      end
    else
      {:ok, p2, rest}
    end
  end

  defp compute_standings_for_pairing(%Tournament{} = tournament) do
    matches = Map.values(tournament.matches)
    base = Map.new(tournament.participants, &{&1.id, Standings.new(&1.id)})

    standings_map =
      matches
      |> Enum.filter(&(&1.status == :complete))
      |> Enum.reduce(base, &apply_match_result/2)

    buchholz_scores = compute_buchholz_all(standings_map, matches)

    standings_map
    |> Map.values()
    |> Enum.map(fn s ->
      buchholz = Map.get(buchholz_scores, s.participant_id, 0)
      %{s | tiebreaker_scores: %{buchholz: buchholz}}
    end)
    |> Enum.sort_by(fn s ->
      {
        -Standings.points(s),
        -Map.get(s.tiebreaker_scores, :buchholz, 0),
        -(s.game_wins - s.game_losses)
      }
    end)
  end

  defp apply_match_result(%Match{winner_id: w, loser_id: l, score: score}, standings_map)
       when w != nil do
    standings_map
    |> Map.update(w, Standings.new(w), fn s ->
      gw = if score, do: Score.p1_wins(score), else: 1
      gl = if score, do: Score.p2_wins(score), else: 0
      %{s | wins: s.wins + 1, game_wins: s.game_wins + gw, game_losses: s.game_losses + gl}
    end)
    |> Map.update(l, Standings.new(l), fn s ->
      gw = if score, do: Score.p2_wins(score), else: 0
      gl = if score, do: Score.p1_wins(score), else: 1
      %{s | losses: s.losses + 1, game_wins: s.game_wins + gw, game_losses: s.game_losses + gl}
    end)
  end

  defp apply_match_result(%Match{p1_id: p1, p2_id: p2, score: score}, standings_map)
       when score != nil do
    case Score.winner(score) do
      :tie ->
        standings_map
        |> Map.update(p1, Standings.new(p1), fn s ->
          %{s | draws: s.draws + 1}
        end)
        |> Map.update(p2, Standings.new(p2), fn s ->
          %{s | draws: s.draws + 1}
        end)

      _ ->
        standings_map
    end
  end

  defp apply_match_result(_match, standings_map), do: standings_map

  defp compute_buchholz_all(standings_map, matches) do
    Map.new(standings_map, fn {id, _} ->
      score =
        matches
        |> Enum.filter(&(&1.status == :complete))
        |> Enum.flat_map(fn m ->
          cond do
            m.p1_id == id -> [m.p2_id]
            m.p2_id == id -> [m.p1_id]
            true -> []
          end
        end)
        |> Enum.reject(&is_nil/1)
        |> Enum.reduce(0, fn opp_id, acc ->
          opp = Map.get(standings_map, opp_id, Standings.new(opp_id))
          acc + opp.wins
        end)

      {id, score}
    end)
  end

  defp already_played_pairs(%Tournament{matches: matches}) do
    matches
    |> Map.values()
    |> Enum.filter(&(&1.p1_id != nil and &1.p2_id != nil))
    |> Enum.map(&{&1.p1_id, &1.p2_id})
    |> MapSet.new()
  end

  defp current_round_number(%Tournament{rounds: []}), do: 0
  defp current_round_number(%Tournament{rounds: rounds}), do: length(rounds)

  defp current_round_complete?(%Tournament{rounds: []}, _round), do: true

  defp current_round_complete?(%Tournament{matches: matches, rounds: rounds}, _round) do
    current_round_ids = List.last(rounds, [])

    current_round_ids
    |> Enum.map(&Map.get(matches, &1))
    |> Enum.reject(&is_nil/1)
    |> Enum.all?(&(&1.status == :complete))
  end

  defp max_rounds(%Tournament{config: config, participants: participants}) do
    case config.swiss_rounds do
      nil -> ceil(:math.log2(max(length(participants), 2)))
      n -> n
    end
  end

  @impl true
  def standings(%Tournament{} = tournament) do
    compute_standings_for_pairing(tournament)
    |> Enum.with_index(1)
    |> Enum.map(fn {s, i} -> %{s | rank: i} end)
  end

  @impl true
  def complete?(%Tournament{} = tournament) do
    current_round = current_round_number(tournament)
    max = max_rounds(tournament)

    current_round >= max and current_round_complete?(tournament, current_round)
  end

  defp match_id(round, position), do: "sw_r#{round}m#{position}"
end
