defmodule Bracket.Render.ASCII do
  @moduledoc false

  alias Bracket.{Match, Tournament}

  @name_width 12

  @spec render(Tournament.t()) :: binary()
  def render(%Tournament{format: f} = t) when f in [:single_elimination, :double_elimination] do
    render_elimination(t)
  end

  def render(%Tournament{} = t) do
    render_standings_table(t)
  end

  defp render_elimination(%Tournament{rounds: []} = _t), do: "(no matches generated)"

  defp render_elimination(%Tournament{format: :double_elimination} = t) do
    matches = t.matches

    {wb_rounds, lb_gf_rounds} =
      Enum.split_while(t.rounds, fn ids ->
        m = matches[List.first(ids)]
        m != nil and m.round > 0
      end)

    wb_section = render_bracket_section(%{t | rounds: wb_rounds}, "Winners Bracket")
    lb_section = render_lb_gf_section(lb_gf_rounds, matches, t.participants)

    [wb_section, "", lb_section] |> Enum.join("\n")
  end

  defp render_elimination(%Tournament{} = t) do
    render_bracket_section(t, nil)
  end

  defp render_bracket_section(%Tournament{} = t, title) do
    rounds = t.rounds
    matches = t.matches
    participants = Map.new(t.participants, &{&1.id, &1})
    num_rounds = length(rounds)
    first_round_count = length(List.first(rounds))
    total_rows = first_round_count * 4 - 1

    # Phase 1: structural elements — p1/p2 name rows, connector chars, bridge dashes
    grid =
      rounds
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {round_ids, col_idx}, g ->
        round_ids
        |> Enum.with_index()
        |> Enum.reduce(g, fn {match_id, match_idx}, g2 ->
          match = matches[match_id]
          if match, do: draw_structure(g2, match, col_idx, match_idx, participants), else: g2
        end)
      end)

    # Phase 2: winner names on top of bridge dashes.
    # Bridge rows (p1_j, p2_j) get the feeder match winner names.
    # Junction rows get the match winner name.
    grid =
      rounds
      |> Enum.with_index()
      |> Enum.reduce(grid, fn {round_ids, col_idx}, g ->
        round_ids
        |> Enum.with_index()
        |> Enum.reduce(g, fn {match_id, match_idx}, g2 ->
          match = matches[match_id]

          if match do
            draw_winner_name(
              g2,
              rounds,
              matches,
              match,
              col_idx,
              match_idx,
              num_rounds,
              participants
            )
          else
            g2
          end
        end)
      end)

    total_width = corner_x(num_rounds - 1) + @name_width + 6
    header = build_header(rounds, matches, num_rounds)

    rows =
      Enum.map(0..(total_rows - 1), fn r ->
        Enum.map(0..(total_width - 1), fn c -> Map.get(grid, {r, c}, ?\s) end)
        |> List.to_string()
        |> String.trim_trailing()
      end)

    if title do
      [title, header, "" | rows] |> Enum.join("\n")
    else
      [header, "" | rows] |> Enum.join("\n")
    end
  end

  defp render_lb_gf_section(lb_gf_rounds, matches, participants_list) do
    {lb_rounds, gf_rounds} =
      Enum.split_while(lb_gf_rounds, fn ids ->
        m = matches[List.first(ids)]
        m != nil and m.round < 0
      end)

    lb_sections = Enum.chunk_every(lb_rounds, 2)
    bar = String.duplicate("─", 60)

    make_t = fn rounds ->
      %Tournament{rounds: rounds, matches: matches, participants: participants_list}
    end

    lb_texts = Enum.map(lb_sections, &render_bracket_section(make_t.(&1), nil))
    gf_texts = Enum.map(gf_rounds, &render_bracket_section(make_t.([&1]), nil))

    all_texts = lb_texts ++ gf_texts

    (["Losers Bracket", bar] ++ Enum.intersperse(all_texts, bar))
    |> Enum.join("\n")
  end

  # corner_x(c) is the x position of the ┐/├/┘/│ connecting column c to column c+1
  defp corner_x(col_idx) do
    @name_width + 3 + col_idx * (@name_width + 7)
  end

  defp j_row(col_idx, match_idx) do
    trunc((4 * match_idx + 2) * :math.pow(2, col_idx)) - 1
  end

  # Phase 1: draw structural characters (names in col 0, connectors, bridge dashes)
  defp draw_structure(grid, match, 0, match_idx, participants) do
    j = j_row(0, match_idx)
    cx = corner_x(0)
    p1 = pad(name_label(match.p1_id, participants))
    p2 = pad(name_label(match.p2_id, participants))

    grid
    |> put_str(j - 1, 0, p1 <> " ──┐")
    |> put_char(j, cx, ?├)
    |> put_str(j + 1, 0, p2 <> " ──┘")
  end

  defp draw_structure(grid, _match, col_idx, match_idx, _participants) do
    j = j_row(col_idx, match_idx)
    cx = corner_x(col_idx)
    prev_cx = corner_x(col_idx - 1)
    p1_j = j_row(col_idx - 1, match_idx * 2)
    p2_j = j_row(col_idx - 1, match_idx * 2 + 1)

    grid =
      Enum.reduce((prev_cx + 1)..(cx - 1), grid, fn x, g ->
        g
        |> put_char(p1_j, x, ?─)
        |> put_char(p2_j, x, ?─)
      end)

    Enum.reduce(p1_j..p2_j, grid, fn row, g ->
      char =
        cond do
          row == p1_j -> ?┐
          row == j -> ?├
          row == p2_j -> ?┘
          true -> ?│
        end

      put_char(g, row, cx, char)
    end)
  end

  # Phase 2: draw winner names.
  # For col 0 when it's the final column, show the winner at the junction.
  # For col >= 1, also fill bridge rows with the feeder match winners so every
  # horizontal line carries a name.
  defp draw_winner_name(grid, _rounds, _matches, match, 0, _match_idx, num_rounds, participants) do
    if num_rounds == 1 do
      j = j_row(0, 0)
      cx = corner_x(0)
      put_str(grid, j, cx + 1, "── " <> truncate(winner_label(match, participants)))
    else
      grid
    end
  end

  defp draw_winner_name(
         grid,
         rounds,
         matches,
         match,
         col_idx,
         match_idx,
         num_rounds,
         participants
       ) do
    is_last = col_idx == num_rounds - 1
    j = j_row(col_idx, match_idx)
    cx = corner_x(col_idx)
    prev_cx = corner_x(col_idx - 1)
    p1_j = j_row(col_idx - 1, match_idx * 2)
    p2_j = j_row(col_idx - 1, match_idx * 2 + 1)

    prev_round = Enum.at(rounds, col_idx - 1)
    feeder1 = matches[Enum.at(prev_round, match_idx * 2)]
    feeder2 = matches[Enum.at(prev_round, match_idx * 2 + 1)]

    w1 = winner_label(feeder1, participants)
    w2 = winner_label(feeder2, participants)
    w = winner_label(match, participants)

    # Bridge row at p1_j: feeder 1 winner advancing right, corner ┐
    grid = put_str(grid, p1_j, prev_cx + 1, connector_str(w1, :top))
    # Bridge row at p2_j: feeder 2 winner advancing right, corner ┘
    grid = put_str(grid, p2_j, prev_cx + 1, connector_str(w2, :bottom))

    # Junction row: this match's winner advancing right
    if is_last do
      put_str(grid, j, cx + 1, "── " <> truncate(w))
    else
      corner = if rem(match_idx, 2) == 0, do: :top, else: :bottom
      put_str(grid, j, cx + 1, connector_str(w, corner))
    end
  end

  # Builds "── Name ────────────┐" or "──┘" variant.
  # Total length = @name_width + 7, which spans from corner_x(c)+1 to corner_x(c+1).
  # Builds a string of exactly (@name_width + 7) chars:
  # "── Name ──────────┐" or "──┘" variant.
  # Starts at the position right after a ├ and fills to the next corner exactly.
  defp connector_str(name, corner_type) do
    name = truncate(name)
    len = String.length(name)
    fill = String.duplicate("─", @name_width - len + 1)
    corner = if corner_type == :top, do: "┐", else: "┘"
    "─── " <> name <> " " <> fill <> corner
  end

  defp name_label(nil, _participants), do: "TBD"

  defp name_label(id, participants) do
    case Map.get(participants, id) do
      nil -> "TBD"
      p -> truncate(p.name)
    end
  end

  defp winner_label(nil, _participants), do: "?"
  defp winner_label(%Match{winner_id: nil}, _participants), do: "?"

  defp winner_label(%Match{winner_id: id}, participants) do
    name_label(id, participants)
  end

  defp pad(name), do: String.pad_trailing(name, @name_width)
  defp truncate(s), do: String.slice(s, 0, @name_width)

  defp put_char(grid, row, col, char) when is_integer(char) do
    Map.put(grid, {row, col}, char)
  end

  defp put_str(grid, row, col, str) do
    str
    |> String.to_charlist()
    |> Enum.with_index()
    |> Enum.reduce(grid, fn {char, i}, g -> put_char(g, row, col + i, char) end)
  end

  defp build_header(rounds, matches, num_rounds) do
    col_width = @name_width + 7

    rounds
    |> Enum.with_index()
    |> Enum.map(fn {round_ids, col_idx} ->
      match = matches[List.first(round_ids)]
      label = round_label(match, col_idx, num_rounds)
      String.pad_trailing(label, col_width)
    end)
    |> Enum.join("")
    |> String.trim_trailing()
  end

  defp round_label(%Match{id: "gf"}, _col_idx, _num_rounds), do: "Grand Finals"
  defp round_label(%Match{id: "gf_reset"}, _col_idx, _num_rounds), do: "GF Reset"
  defp round_label(%Match{id: "3rd"}, _col_idx, _num_rounds), do: "3rd Place"

  defp round_label(%Match{round: r}, _col_idx, _num_rounds) when r < 0 do
    "LB Round #{abs(r)}"
  end

  defp round_label(_match, col_idx, num_rounds) do
    rounds_from_end = num_rounds - col_idx

    cond do
      rounds_from_end == 1 -> "Final"
      rounds_from_end == 2 -> "Semifinal"
      rounds_from_end == 3 -> "Quarterfinal"
      true -> "Round #{col_idx + 1}"
    end
  end

  defp render_standings_table(%Tournament{} = tournament) do
    standings = Bracket.standings(tournament)
    participants_by_id = Map.new(tournament.participants, &{&1.id, &1})

    name_width =
      standings
      |> Enum.map(fn s ->
        p = Map.get(participants_by_id, s.participant_id)
        if p, do: String.length(p.name), else: 3
      end)
      |> Enum.max(fn -> 10 end)
      |> max(10)

    top = standings_separator(name_width, :top)
    mid = standings_separator(name_width, :mid)
    bot = standings_separator(name_width, :bot)
    header = standings_header(name_width)
    rows = Enum.map(standings, &standings_row(&1, participants_by_id, name_width))

    ([top, header, mid] ++ rows ++ [bot]) |> Enum.join("\n")
  end

  defp standings_separator(name_width, :top) do
    "┌────┬─#{String.duplicate("─", name_width)}─┬───┬───┬───┬─────┐"
  end

  defp standings_separator(name_width, :mid) do
    "├────┼─#{String.duplicate("─", name_width)}─┼───┼───┼───┼─────┤"
  end

  defp standings_separator(name_width, :bot) do
    "└────┴─#{String.duplicate("─", name_width)}─┴───┴───┴───┴─────┘"
  end

  defp standings_header(name_width) do
    "│ #  │ #{String.pad_trailing("Name", name_width)} │ W │ L │ D │  GD │"
  end

  defp standings_row(standing, participants_by_id, name_width) do
    p = Map.get(participants_by_id, standing.participant_id)
    name = if p, do: p.name, else: standing.participant_id
    gd = standing.game_wins - standing.game_losses
    gd_str = if gd >= 0, do: "+#{gd}", else: "#{gd}"

    rank = String.pad_leading("#{standing.rank}", 2)
    name_padded = String.pad_trailing(name, name_width)
    wins = String.pad_leading("#{standing.wins}", 1)
    losses = String.pad_leading("#{standing.losses}", 1)
    draws = String.pad_leading("#{standing.draws}", 1)
    gd_padded = String.pad_leading(gd_str, 3)

    "│ #{rank} │ #{name_padded} │ #{wins} │ #{losses} │ #{draws} │ #{gd_padded} │"
  end
end
