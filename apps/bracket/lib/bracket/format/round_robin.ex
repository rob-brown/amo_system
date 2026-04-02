defmodule Bracket.Format.RoundRobin do
  @moduledoc false

  @behaviour Bracket.Format

  alias Bracket.{Match, Score, Standings, Tournament}

  @impl true
  def generate_matches(%Tournament{} = tournament) do
    participants = tournament.participants
    n = length(participants)

    if n < 2 do
      {:error, :not_enough_participants}
    else
      {matches, rounds} = schedule(participants)

      rounds_of_ids = Enum.map(rounds, fn round -> Enum.map(round, & &1.id) end)
      matches_map = Map.new(matches, &{&1.id, &1})

      tournament =
        %{tournament | matches: matches_map, rounds: rounds_of_ids}
        |> Tournament.touch()

      {:ok, tournament}
    end
  end

  defp schedule(participants) do
    n = length(participants)
    # For odd N, insert :bye as the fixed position so every player rotates through it
    slots = if rem(n, 2) == 0, do: participants, else: [:bye | participants]
    total = length(slots)
    round_count = total - 1

    rounds =
      Enum.map(0..(round_count - 1), fn round_idx ->
        rotated = circle_rotate(slots, round_idx)
        pairs = circle_pairs(rotated)

        pairs
        |> Enum.reject(fn {p1, p2} -> p1 == :bye or p2 == :bye end)
        |> Enum.with_index()
        |> Enum.map(fn {{p1, p2}, pos} ->
          Match.new(
            id: match_id(round_idx + 1, pos),
            round: round_idx + 1,
            position: pos,
            p1_id: p1.id,
            p2_id: p2.id,
            status: :ready
          )
        end)
      end)

    matches = List.flatten(rounds)
    {matches, rounds}
  end

  # Fix the first element; rotate the rest by round_idx positions clockwise
  defp circle_rotate([fixed | rest], round_idx) do
    n = length(rest)
    shift = rem(round_idx, n)
    {head, tail} = Enum.split(rest, n - shift)
    [fixed | tail ++ head]
  end

  # Pair top half with bottom half (reversed) in a circle
  defp circle_pairs(slots) do
    half = div(length(slots), 2)
    top = Enum.take(slots, half)
    bottom = slots |> Enum.drop(half) |> Enum.reverse()
    Enum.zip(top, bottom)
  end

  @impl true
  def standings(%Tournament{} = tournament) do
    matches = Map.values(tournament.matches)

    base = Map.new(tournament.participants, &{&1.id, Standings.new(&1.id)})

    standings_map =
      matches
      |> Enum.filter(&(&1.status == :complete))
      |> Enum.reduce(base, &apply_match_result/2)

    standings_map
    |> Map.values()
    |> compute_tiebreakers(standings_map, matches)
    |> rank()
  end

  defp apply_match_result(
         %Match{winner_id: nil, loser_id: nil, score: score} = match,
         standings_map
       )
       when score != nil do
    case Score.winner(score) do
      :tie ->
        standings_map
        |> Map.update(match.p1_id, Standings.new(match.p1_id), fn s ->
          gw = Score.p1_wins(score)
          gl = Score.p2_wins(score)
          %{s | draws: s.draws + 1, game_wins: s.game_wins + gw, game_losses: s.game_losses + gl}
        end)
        |> Map.update(match.p2_id, Standings.new(match.p2_id), fn s ->
          gw = Score.p2_wins(score)
          gl = Score.p1_wins(score)
          %{s | draws: s.draws + 1, game_wins: s.game_wins + gw, game_losses: s.game_losses + gl}
        end)

      winner ->
        apply_decisive_result(match, winner, score, standings_map)
    end
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

  defp apply_match_result(_match, standings_map), do: standings_map

  defp apply_decisive_result(match, :p1, score, standings_map) do
    standings_map
    |> Map.update(match.p1_id, Standings.new(match.p1_id), fn s ->
      gw = Score.p1_wins(score)
      gl = Score.p2_wins(score)
      %{s | wins: s.wins + 1, game_wins: s.game_wins + gw, game_losses: s.game_losses + gl}
    end)
    |> Map.update(match.p2_id, Standings.new(match.p2_id), fn s ->
      gw = Score.p2_wins(score)
      gl = Score.p1_wins(score)
      %{s | losses: s.losses + 1, game_wins: s.game_wins + gw, game_losses: s.game_losses + gl}
    end)
  end

  defp apply_decisive_result(match, :p2, score, standings_map) do
    apply_decisive_result(
      %{match | p1_id: match.p2_id, p2_id: match.p1_id},
      :p1,
      %Score{sets: Enum.map(score.sets, fn {a, b} -> {b, a} end)},
      standings_map
    )
  end

  defp compute_tiebreakers(standings_list, standings_map, matches) do
    Enum.map(standings_list, fn s ->
      buchholz = compute_buchholz(s.participant_id, standings_map, matches)
      sb = compute_sonneborn_berger(s.participant_id, standings_map, matches)

      %{
        s
        | tiebreaker_scores:
            Map.merge(s.tiebreaker_scores, %{buchholz: buchholz, sonneborn_berger: sb})
      }
    end)
  end

  defp compute_buchholz(participant_id, standings_map, matches) do
    opponents = opponents_of(participant_id, matches)

    Enum.reduce(opponents, 0, fn opp_id, acc ->
      opp = Map.get(standings_map, opp_id, Standings.new(opp_id))
      acc + opp.wins
    end)
  end

  defp compute_sonneborn_berger(participant_id, standings_map, matches) do
    completed = Enum.filter(matches, &(&1.status == :complete))

    Enum.reduce(completed, 0.0, fn match, acc ->
      cond do
        match.p1_id == participant_id && match.winner_id == participant_id ->
          opp = Map.get(standings_map, match.p2_id, Standings.new(match.p2_id))
          acc + opp.wins

        match.p2_id == participant_id && match.winner_id == participant_id ->
          opp = Map.get(standings_map, match.p1_id, Standings.new(match.p1_id))
          acc + opp.wins

        match.p1_id == participant_id && match.winner_id == nil ->
          opp = Map.get(standings_map, match.p2_id, Standings.new(match.p2_id))
          acc + opp.wins * 0.5

        match.p2_id == participant_id && match.winner_id == nil ->
          opp = Map.get(standings_map, match.p1_id, Standings.new(match.p1_id))
          acc + opp.wins * 0.5

        true ->
          acc
      end
    end)
  end

  defp opponents_of(participant_id, matches) do
    matches
    |> Enum.filter(&(&1.status == :complete))
    |> Enum.flat_map(fn m ->
      cond do
        m.p1_id == participant_id -> [m.p2_id]
        m.p2_id == participant_id -> [m.p1_id]
        true -> []
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp rank(standings) do
    standings
    |> Enum.sort_by(fn s ->
      {
        -Standings.points(s),
        -Standings.game_differential(s),
        -Map.get(s.tiebreaker_scores, :sonneborn_berger, 0),
        -Map.get(s.tiebreaker_scores, :buchholz, 0)
      }
    end)
    |> Enum.with_index(1)
    |> Enum.map(fn {s, i} -> %{s | rank: i} end)
  end

  @impl true
  def complete?(%Tournament{matches: matches}) do
    matches
    |> Map.values()
    |> Enum.reject(&(&1.status == :bye))
    |> Enum.all?(&(&1.status == :complete))
  end

  defp match_id(round, position), do: "rr_r#{round}m#{position}"
end
