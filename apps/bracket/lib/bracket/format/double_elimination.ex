defmodule Bracket.Format.DoubleElimination do
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
      wb_rounds = round(:math.log2(size))
      positions = Seeding.bracket_positions(size)
      participant_by_seed = Map.new(participants, &{&1.seed, &1})

      {matches, rounds} =
        build_double_bracket(positions, participant_by_seed, wb_rounds, tournament.config)

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

  defp build_double_bracket(positions, participant_by_seed, wb_rounds, config) do
    {_wb_matches, wb_rounds_list} =
      build_winners_bracket(positions, participant_by_seed, wb_rounds)

    wb_rounds_list = link_wb_loser_feeds(wb_rounds_list)

    {_lb_matches, lb_rounds_list} = build_losers_bracket(wb_rounds, wb_rounds_list)

    {gf_matches, wb_rounds_linked, lb_rounds_linked} =
      build_grand_finals(wb_rounds_list, lb_rounds_list, config)

    all_rounds = wb_rounds_linked ++ lb_rounds_linked ++ [gf_matches]
    all_matches = List.flatten(all_rounds)

    {all_matches, all_rounds}
  end

  # Sets loser_feeds on all WB matches so losers flow into the correct LB slot.
  #
  # WB round r losers drop into LB round (2r-1):
  #   - r=1: adjacent pairs share one LB match (even pos → :p1, odd pos → :p2)
  #   - r>1: each loser goes into the corresponding LB match as :p2
  defp link_wb_loser_feeds(wb_rounds_list) do
    wb_rounds_list
    |> Enum.with_index(1)
    |> Enum.map(fn {round, r} ->
      round
      |> Enum.with_index()
      |> Enum.map(fn {match, pos} ->
        lb_round = 2 * r - 1

        {lb_pos, slot} =
          if r == 1 do
            {div(pos, 2), if(rem(pos, 2) == 0, do: :p1, else: :p2)}
          else
            {pos, :p2}
          end

        %{match | loser_feeds: {lb_id(lb_round, lb_pos), slot}}
      end)
    end)
  end

  defp build_winners_bracket(positions, participant_by_seed, wb_rounds) do
    pairs = Enum.chunk_every(positions, 2)

    round1 =
      pairs
      |> Enum.with_index()
      |> Enum.map(fn {[s1, s2], pos} ->
        p1 = Map.get(participant_by_seed, s1)
        p2 = Map.get(participant_by_seed, s2)

        Match.new(
          id: wb_id(1, pos),
          round: 1,
          position: pos,
          p1_id: if(p1, do: p1.id),
          p2_id: if(p2, do: p2.id),
          status: if(p1 && p2, do: :ready, else: :pending)
        )
      end)

    build_wb_rounds([round1], 2, wb_rounds)
  end

  defp build_wb_rounds(rounds, current, total) when current > total do
    matches = List.flatten(rounds)
    {matches, rounds}
  end

  defp build_wb_rounds(rounds, current, total) do
    prev = List.last(rounds)
    pairs = Enum.chunk_every(prev, 2)

    new_round =
      pairs
      |> Enum.with_index()
      |> Enum.map(fn {[m1, m2], pos} ->
        Match.new(
          id: wb_id(current, pos),
          round: current,
          position: pos,
          p1_prereq_match: m1.id,
          p2_prereq_match: m2.id,
          status: :pending
        )
      end)

    prev_with_feeds =
      prev
      |> Enum.chunk_every(2)
      |> Enum.with_index()
      |> Enum.flat_map(fn {[m1, m2], pos} ->
        target = wb_id(current, pos)
        [%{m1 | winner_feeds: {target, :p1}}, %{m2 | winner_feeds: {target, :p2}}]
      end)

    updated_rounds = List.replace_at(rounds, -1, prev_with_feeds)
    build_wb_rounds(updated_rounds ++ [new_round], current + 1, total)
  end

  defp build_losers_bracket(wb_rounds, wb_rounds_list) do
    lb_round_count = wb_rounds * 2 - 1
    build_lb_rounds([], wb_rounds_list, lb_round_count, 1)
  end

  defp build_lb_rounds(lb_rounds_acc, _wb_rounds_list, total_lb, current)
       when current > total_lb do
    matches = List.flatten(lb_rounds_acc)
    {matches, lb_rounds_acc}
  end

  defp build_lb_rounds(lb_rounds_acc, wb_rounds_list, total_lb, current) do
    wb_drop_round = div(current + 1, 2)
    is_drop_round = rem(current, 2) == 1

    prev_lb = List.last(lb_rounds_acc)
    size = lb_round_size(current, length(wb_rounds_list))

    new_round =
      if is_drop_round do
        wb_losers = get_wb_round_losers(wb_rounds_list, wb_drop_round)
        build_lb_drop_round(wb_losers, prev_lb, current, size)
      else
        build_lb_progression_round(prev_lb, current, size)
      end

    lb_rounds_acc_updated = update_lb_feeds(lb_rounds_acc, new_round, current, is_drop_round)

    build_lb_rounds(lb_rounds_acc_updated ++ [new_round], wb_rounds_list, total_lb, current + 1)
  end

  defp lb_round_size(lb_round, wb_rounds) do
    max(
      1,
      div(
        next_power_of_two(trunc(:math.pow(2, wb_rounds - 1))),
        trunc(:math.pow(2, div(lb_round - 1, 2) + 1))
      )
    )
  end

  defp get_wb_round_losers(wb_rounds_list, wb_round) do
    wb_rounds_list
    |> Enum.at(wb_round - 1, [])
  end

  defp build_lb_drop_round(wb_losers, nil, lb_round, _size) do
    wb_losers
    |> Enum.chunk_every(2)
    |> Enum.with_index()
    |> Enum.map(fn {pair, pos} ->
      [m1 | rest] = pair
      m2 = List.first(rest)

      Match.new(
        id: lb_id(lb_round, pos),
        round: -lb_round,
        position: pos,
        p1_prereq_match: m1.id,
        p2_prereq_match: if(m2, do: m2.id),
        status: :pending
      )
    end)
  end

  defp build_lb_drop_round(wb_losers, prev_lb, lb_round, _size) do
    wb_losers
    |> Enum.with_index()
    |> Enum.map(fn {wb_match, pos} ->
      prev_match = Enum.at(prev_lb, pos)

      Match.new(
        id: lb_id(lb_round, pos),
        round: -lb_round,
        position: pos,
        p1_prereq_match: if(prev_match, do: prev_match.id),
        p2_prereq_match: wb_match.id,
        status: :pending
      )
    end)
  end

  defp build_lb_progression_round(prev_lb, lb_round, _size) do
    prev_lb
    |> Enum.chunk_every(2)
    |> Enum.with_index()
    |> Enum.map(fn {matches, pos} ->
      [m1 | rest] = matches
      m2 = List.first(rest)

      Match.new(
        id: lb_id(lb_round, pos),
        round: -lb_round,
        position: pos,
        p1_prereq_match: m1.id,
        p2_prereq_match: if(m2, do: m2.id),
        status: :pending
      )
    end)
  end

  defp update_lb_feeds(lb_rounds_acc, _new_round, lb_round, is_drop_round) do
    if lb_round == 1 or (is_drop_round and lb_rounds_acc == []) do
      lb_rounds_acc
    else
      prev_lb = List.last(lb_rounds_acc)

      updated_prev =
        prev_lb
        |> Enum.chunk_every(if(is_drop_round, do: 1, else: 2))
        |> Enum.with_index()
        |> Enum.flat_map(fn {matches, pos} ->
          target = lb_id(lb_round, pos)

          case matches do
            [m] -> [%{m | winner_feeds: {target, :p1}}]
            [m1, m2] -> [%{m1 | winner_feeds: {target, :p1}}, %{m2 | winner_feeds: {target, :p2}}]
          end
        end)

      List.replace_at(lb_rounds_acc, -1, updated_prev)
    end
  end

  defp build_grand_finals(wb_rounds_list, lb_rounds_list, config) do
    wb_final = wb_rounds_list |> List.last([]) |> List.first()
    lb_final = lb_rounds_list |> List.last([]) |> List.first()

    gf =
      Match.new(
        id: "gf",
        round: 0,
        position: 0,
        p1_prereq_match: if(wb_final, do: wb_final.id),
        p2_prereq_match: if(lb_final, do: lb_final.id),
        status: :pending
      )

    gf_matches =
      case config.grand_finals_modifier do
        :reset ->
          gf_reset =
            Match.new(
              id: "gf_reset",
              round: 0,
              position: 1,
              p1_prereq_match: "gf",
              p2_prereq_match: "gf",
              status: :pending
            )

          gf_with_feed = %{gf | winner_feeds: {"gf_reset", :p1}, loser_feeds: {"gf_reset", :p2}}
          [gf_with_feed, gf_reset]

        :standard ->
          [gf]
      end

    wb_rounds_linked =
      if wb_final do
        updated = %{wb_final | winner_feeds: {"gf", :p1}}
        List.replace_at(wb_rounds_list, -1, [updated])
      else
        wb_rounds_list
      end

    lb_rounds_linked =
      if lb_final do
        updated = %{lb_final | winner_feeds: {"gf", :p2}}
        List.replace_at(lb_rounds_list, -1, [updated])
      else
        lb_rounds_list
      end

    {gf_matches, wb_rounds_linked, lb_rounds_linked}
  end

  defp resolve_byes(%Tournament{} = tournament, matches_map) do
    byes =
      matches_map
      |> Map.values()
      |> Enum.filter(fn m ->
        m.p1_id == nil != (m.p2_id == nil) and m.p2_prereq_match == nil
      end)

    Enum.reduce(byes, %{tournament | matches: matches_map}, fn bye_match, t ->
      winner_id = bye_match.p1_id || bye_match.p2_id
      completed = %{bye_match | status: :bye, winner_id: winner_id}

      t
      |> Tournament.put_match(completed)
      |> advance_bye(completed, matches_map)
    end)
  end

  defp advance_bye(
         tournament,
         %Match{winner_feeds: {target_id, slot}, winner_id: winner_id},
         _matches_map
       ) do
    case Tournament.get_match(tournament, target_id) do
      {:ok, target} ->
        updated = place_participant(target, slot, winner_id)
        updated = if Match.ready?(updated), do: %{updated | status: :ready}, else: updated
        Tournament.put_match(tournament, updated)

      {:error, :not_found} ->
        tournament
    end
  end

  defp advance_bye(tournament, %Match{winner_feeds: nil}, _), do: tournament

  defp place_participant(match, :p1, id), do: %{match | p1_id: id}
  defp place_participant(match, :p2, id), do: %{match | p2_id: id}

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
    |> Enum.sort_by(fn s -> {-s.wins, s.losses} end)
    |> Enum.with_index(1)
    |> Enum.map(fn {s, i} -> %{s | rank: i} end)
  end

  defp apply_match_result(%Match{status: :bye}, standings_map), do: standings_map

  defp apply_match_result(%Match{winner_id: nil}, standings_map), do: standings_map

  defp apply_match_result(%Match{winner_id: w, loser_id: l, score: score}, standings_map) do
    standings_map
    |> Map.update(w, Standings.new(w), fn s ->
      gw = if score, do: Bracket.Score.p1_wins(score), else: 1
      gl = if score, do: Bracket.Score.p2_wins(score), else: 0
      %{s | wins: s.wins + 1, game_wins: s.game_wins + gw, game_losses: s.game_losses + gl}
    end)
    |> Map.update(l, Standings.new(l), fn s ->
      gw = if score, do: Bracket.Score.p2_wins(score), else: 0
      gl = if score, do: Bracket.Score.p1_wins(score), else: 1
      %{s | losses: s.losses + 1, game_wins: s.game_wins + gw, game_losses: s.game_losses + gl}
    end)
  end

  @impl true
  def complete?(%Tournament{matches: matches}) do
    case Map.get(matches, "gf") do
      nil -> false
      gf -> gf.status == :complete
    end
  end

  defp next_power_of_two(n) do
    Stream.iterate(1, &(&1 * 2))
    |> Enum.find(&(&1 >= n))
  end

  defp wb_id(round, pos), do: "wb_r#{round}m#{pos}"
  defp lb_id(round, pos), do: "lb_r#{round}m#{pos}"
end
