defmodule Bracket.Format.SingleElimination do
  @moduledoc false

  @behaviour Bracket.Format

  alias Bracket.{Match, Seeding, Standings, Tournament}

  @impl true
  def generate_matches(%Tournament{} = tournament) do
    participants = tournament.participants
    n = length(participants)

    if n < 2 do
      {:error, :not_enough_participants}
    else
      size = next_power_of_two(n)
      positions = Seeding.bracket_positions(size)
      participant_by_seed = Map.new(participants, &{&1.seed, &1})

      {matches, rounds} = build_bracket(positions, participant_by_seed, tournament.config)

      rounds_of_ids = Enum.map(rounds, fn round -> Enum.map(round, & &1.id) end)
      matches_map = Map.new(matches, &{&1.id, &1})

      tournament =
        tournament
        |> resolve_byes(matches_map)
        |> then(fn t -> %{t | rounds: rounds_of_ids} end)
        |> Tournament.touch()

      {:ok, tournament}
    end
  end

  defp build_bracket(positions, participant_by_seed, config) do
    total_rounds = round(:math.log2(length(positions)))
    pairs = Enum.chunk_every(positions, 2)

    round1_matches =
      pairs
      |> Enum.with_index()
      |> Enum.map(fn {[s1, s2], pos} ->
        p1 = Map.get(participant_by_seed, s1)
        p2 = Map.get(participant_by_seed, s2)

        Match.new(
          id: match_id(1, pos),
          round: 1,
          position: pos,
          p1_id: if(p1, do: p1.id),
          p2_id: if(p2, do: p2.id),
          status: if(p1 && p2, do: :ready, else: :pending)
        )
      end)

    build_subsequent_rounds(round1_matches, [round1_matches], 2, total_rounds, config)
  end

  defp build_subsequent_rounds(prev_matches, all_rounds, current_round, total_rounds, config)
       when current_round > total_rounds do
    if config.third_place_match do
      add_third_place_match(prev_matches, all_rounds, total_rounds)
    else
      matches = List.flatten(all_rounds)
      rounds = all_rounds
      {matches, rounds}
    end
  end

  defp build_subsequent_rounds(prev_matches, all_rounds, current_round, total_rounds, config) do
    pairs = Enum.chunk_every(prev_matches, 2)

    new_matches =
      pairs
      |> Enum.with_index()
      |> Enum.map(fn {[m1, m2], pos} ->
        Match.new(
          id: match_id(current_round, pos),
          round: current_round,
          position: pos,
          status: :pending
        )
        |> link_prereq(m1, m2)
      end)

    prev_matches_with_feeds =
      prev_matches
      |> Enum.chunk_every(2)
      |> Enum.with_index()
      |> Enum.flat_map(fn {[m1, m2], pos} ->
        target_id = match_id(current_round, pos)

        [
          %{m1 | winner_feeds: {target_id, :p1}},
          %{m2 | winner_feeds: {target_id, :p2}}
        ]
      end)

    updated_rounds = update_last_round(all_rounds, prev_matches_with_feeds)

    build_subsequent_rounds(
      new_matches,
      updated_rounds ++ [new_matches],
      current_round + 1,
      total_rounds,
      config
    )
  end

  defp add_third_place_match(_semifinals, all_rounds, total_rounds) do
    [sf1, sf2] =
      all_rounds
      |> Enum.at(total_rounds - 2)
      |> Enum.take(2)

    third_place =
      Match.new(
        id: "3rd",
        round: total_rounds,
        position: 1
      )

    sf1_updated = %{sf1 | loser_feeds: {"3rd", :p1}}
    sf2_updated = %{sf2 | loser_feeds: {"3rd", :p2}}

    updated = update_matches_in_rounds(all_rounds, [sf1_updated, sf2_updated])
    final_round = List.last(updated) ++ [third_place]
    rounds = List.replace_at(updated, -1, final_round)

    matches = List.flatten(rounds)
    {matches, rounds}
  end

  defp link_prereq(match, m1, m2) do
    %{match | p1_prereq_match: m1.id, p2_prereq_match: m2.id}
  end

  defp update_last_round(rounds, updated_matches) do
    updated_map = Map.new(updated_matches, &{&1.id, &1})

    List.update_at(rounds, -1, fn round ->
      Enum.map(round, &Map.get(updated_map, &1.id, &1))
    end)
  end

  defp update_matches_in_rounds(rounds, updated_matches) do
    updated_map = Map.new(updated_matches, &{&1.id, &1})

    Enum.map(rounds, fn round ->
      Enum.map(round, &Map.get(updated_map, &1.id, &1))
    end)
  end

  defp resolve_byes(%Tournament{} = tournament, matches_map) do
    byes =
      matches_map
      |> Map.values()
      |> Enum.filter(fn m ->
        (m.p1_id != nil and m.p2_id == nil and m.p2_prereq_match == nil) or
          (m.p2_id != nil and m.p1_id == nil and m.p1_prereq_match == nil)
      end)

    Enum.reduce(byes, %{tournament | matches: matches_map}, fn bye_match, t ->
      winner_id = bye_match.p1_id || bye_match.p2_id

      completed = %{bye_match | status: :bye, winner_id: winner_id}

      t
      |> Tournament.put_match(completed)
      |> advance_bye(completed)
    end)
  end

  defp advance_bye(tournament, %Match{winner_feeds: {target_id, slot}, winner_id: winner_id}) do
    case Tournament.get_match(tournament, target_id) do
      {:ok, target} ->
        updated = place_participant(target, slot, winner_id)
        updated = if Match.ready?(updated), do: %{updated | status: :ready}, else: updated
        Tournament.put_match(tournament, updated)

      {:error, :not_found} ->
        tournament
    end
  end

  defp advance_bye(tournament, %Match{winner_feeds: nil}), do: tournament

  defp place_participant(match, :p1, id), do: %{match | p1_id: id}
  defp place_participant(match, :p2, id), do: %{match | p2_id: id}

  @impl true
  def standings(%Tournament{} = tournament) do
    matches = Map.values(tournament.matches)

    base =
      tournament.participants
      |> Map.new(&{&1.id, Standings.new(&1.id)})

    standings_map =
      matches
      |> Enum.filter(&(&1.status == :complete))
      |> Enum.reduce(base, &apply_match_result/2)

    standings_map
    |> Map.values()
    |> rank_elimination()
  end

  defp apply_match_result(%Match{status: :bye}, standings_map), do: standings_map

  defp apply_match_result(%Match{winner_id: w, loser_id: l, score: score}, standings_map) do
    standings_map
    |> update_in([w], fn s ->
      game_wins = if score, do: Bracket.Score.p1_wins(score), else: 1
      game_losses = if score, do: Bracket.Score.p2_wins(score), else: 0

      %{
        s
        | wins: s.wins + 1,
          game_wins: s.game_wins + game_wins,
          game_losses: s.game_losses + game_losses
      }
    end)
    |> update_in([l], fn s ->
      game_wins = if score, do: Bracket.Score.p2_wins(score), else: 0
      game_losses = if score, do: Bracket.Score.p1_wins(score), else: 1

      %{
        s
        | losses: s.losses + 1,
          game_wins: s.game_wins + game_wins,
          game_losses: s.game_losses + game_losses
      }
    end)
  end

  defp rank_elimination(standings) do
    sorted = Enum.sort_by(standings, fn s -> {-s.wins, s.losses} end)

    sorted
    |> Enum.with_index(1)
    |> Enum.map(fn {s, i} -> %{s | rank: i} end)
  end

  @impl true
  def complete?(%Tournament{matches: matches}) do
    matches
    |> Map.values()
    |> Enum.filter(fn m -> m.round == max_round(matches) end)
    |> Enum.all?(&(&1.status == :complete))
  end

  defp max_round(matches) do
    matches
    |> Map.values()
    |> Enum.map(& &1.round)
    |> Enum.max(fn -> 0 end)
  end

  defp next_power_of_two(n) do
    Stream.iterate(1, &(&1 * 2))
    |> Enum.find(&(&1 >= n))
  end

  defp match_id(round, position) do
    "r#{round}m#{position}"
  end
end
