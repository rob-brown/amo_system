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
    participants = Map.new(t.participants, &{&1.id, &1})

    {wb_rounds, lb_gf_rounds} =
      Enum.split_while(t.rounds, fn ids ->
        m = matches[List.first(ids)]
        m != nil and m.round > 0
      end)

    {lb_rounds, gf_rounds} =
      Enum.split_while(lb_gf_rounds, fn ids ->
        m = matches[List.first(ids)]
        m != nil and m.round < 0
      end)

    wb_section = render_wb_with_gf(wb_rounds, gf_rounds, matches, participants)
    lb_section = render_lb_bracket(lb_rounds, matches, participants)

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

  # =========================================================
  # WB + GF rendering (double elimination)
  # =========================================================

  defp render_wb_with_gf(wb_rounds, gf_rounds, matches, participants) do
    # GF and GF Reset share one round entry — split each match into its own column.
    gf_columns = gf_rounds |> List.first([]) |> Enum.map(&[&1])

    num_wb_rounds = length(wb_rounds)
    num_gf_columns = length(gf_columns)
    num_all_rounds = num_wb_rounds + num_gf_columns
    first_round_count = wb_rounds |> List.first([]) |> length() |> max(1)
    wb_final_j = j_row(num_wb_rounds - 1, 0)

    wb_rows = first_round_count * 4 - 1
    gf_rows = if num_gf_columns > 0, do: wb_final_j + num_gf_columns * 2 + 1, else: 0
    total_rows = max(wb_rows, gf_rows)

    grid =
      wb_rounds
      |> Enum.with_index()
      |> Enum.reduce(%{}, fn {round_ids, col_idx}, g ->
        Enum.with_index(round_ids)
        |> Enum.reduce(g, fn {match_id, match_idx}, g2 ->
          match = matches[match_id]
          if match, do: draw_structure(g2, match, col_idx, match_idx, participants), else: g2
        end)
      end)

    grid =
      wb_rounds
      |> Enum.with_index()
      |> Enum.reduce(grid, fn {round_ids, col_idx}, g ->
        Enum.with_index(round_ids)
        |> Enum.reduce(g, fn {match_id, match_idx}, g2 ->
          match = matches[match_id]

          if match do
            draw_winner_name(
              g2,
              wb_rounds,
              matches,
              match,
              col_idx,
              match_idx,
              num_wb_rounds,
              participants
            )
          else
            g2
          end
        end)
      end)

    grid = draw_gf_columns(grid, gf_columns, matches, participants, num_wb_rounds, wb_final_j)

    total_width = corner_x(num_all_rounds - 1) + @name_width + 6
    header = build_header(wb_rounds ++ gf_columns, matches, num_wb_rounds)

    rows =
      Enum.map(0..(total_rows - 1), fn r ->
        Enum.map(0..(total_width - 1), fn c -> Map.get(grid, {r, c}, ?\s) end)
        |> List.to_string()
        |> String.trim_trailing()
      end)

    ["Winners Bracket", header, "" | rows] |> Enum.join("\n")
  end

  defp draw_gf_columns(grid, [], _matches, _participants, _num_wb_rounds, _wb_final_j), do: grid

  defp draw_gf_columns(grid, gf_rounds, matches, participants, num_wb_rounds, wb_final_j) do
    gf_id = gf_rounds |> List.first() |> List.first()
    gf_match = matches[gf_id]

    gf_col = num_wb_rounds
    gf_cx = corner_x(gf_col)
    prev_cx = corner_x(gf_col - 1)

    p1_j = wb_final_j
    p2_j = wb_final_j + 2
    gf_j = wb_final_j + 1

    grid =
      Enum.reduce((prev_cx + 1)..(gf_cx - 1), grid, fn x, g ->
        put_char(g, p1_j, x, ?─)
      end)

    grid =
      Enum.reduce(p1_j..p2_j, grid, fn row, g ->
        char =
          cond do
            row == p1_j -> ?┐
            row == gf_j -> ?├
            row == p2_j -> ?┘
            true -> ?│
          end

        put_char(g, row, gf_cx, char)
      end)

    lb_winner = lb_final_winner(gf_match, matches, participants)
    grid = put_str(grid, p2_j, prev_cx + 1, wide_entry_str(lb_winner, :bottom))

    wb_final = gf_match && matches[gf_match.p1_prereq_match]
    wb_winner = winner_label(wb_final, participants)
    grid = put_str(grid, p1_j, prev_cx + 1, connector_str(wb_winner, :top))

    has_reset = length(gf_rounds) > 1
    gf_winner = winner_label(gf_match, participants)

    grid =
      if has_reset do
        put_str(grid, gf_j, gf_cx + 1, connector_str(gf_winner, :top))
      else
        put_str(grid, gf_j, gf_cx + 1, "── " <> truncate(gf_winner))
      end

    if has_reset do
      draw_gf_reset_column(grid, gf_rounds, matches, participants, num_wb_rounds, gf_j, gf_match)
    else
      grid
    end
  end

  defp draw_gf_reset_column(grid, gf_rounds, matches, participants, num_wb_rounds, gf_j, gf_match) do
    gf_reset_id = gf_rounds |> Enum.at(1) |> List.first()
    gf_reset = matches[gf_reset_id]

    reset_col = num_wb_rounds + 1
    reset_cx = corner_x(reset_col)
    gf_cx = corner_x(num_wb_rounds)

    p1_j = gf_j
    p2_j = gf_j + 2
    reset_j = gf_j + 1

    grid =
      Enum.reduce((gf_cx + 1)..(reset_cx - 1), grid, fn x, g ->
        g |> put_char(p1_j, x, ?─) |> put_char(p2_j, x, ?─)
      end)

    grid =
      Enum.reduce(p1_j..p2_j, grid, fn row, g ->
        char =
          cond do
            row == p1_j -> ?┐
            row == reset_j -> ?├
            row == p2_j -> ?┘
            true -> ?│
          end

        put_char(g, row, reset_cx, char)
      end)

    gf_winner = winner_label(gf_match, participants)
    gf_loser = loser_label(gf_match, participants)
    grid = put_str(grid, p1_j, gf_cx + 1, connector_str(gf_winner, :top))
    grid = put_str(grid, p2_j, gf_cx + 1, connector_str(gf_loser, :bottom))

    reset_winner = winner_label(gf_reset, participants)
    put_str(grid, reset_j, reset_cx + 1, "── " <> truncate(reset_winner))
  end

  # =========================================================
  # LB single connected bracket rendering
  # =========================================================

  defp render_lb_bracket([], _matches, _participants), do: "Losers Bracket\n(no matches)"

  defp render_lb_bracket(lb_rounds, matches, participants) do
    lb_col_map = build_lb_col_map(lb_rounds)
    num_cols = length(lb_rounds)

    lb_final_id = lb_rounds |> List.last() |> List.first()
    {positions, total_height} = compute_lb_tree(lb_final_id, matches, lb_col_map, 0)

    grid =
      Enum.reduce(positions, %{}, fn {match_id, {j, p1_row, p2_row}}, g ->
        match = matches[match_id]
        col_idx = lb_col_map[match_id]
        draw_lb_structure(g, match, col_idx, j, p1_row, p2_row, lb_col_map, participants)
      end)

    grid =
      Enum.reduce(positions, grid, fn {match_id, {j, p1_row, p2_row}}, g ->
        match = matches[match_id]
        col_idx = lb_col_map[match_id]

        draw_lb_winner_names(
          g,
          match,
          col_idx,
          j,
          p1_row,
          p2_row,
          lb_col_map,
          matches,
          participants,
          num_cols
        )
      end)

    total_width = corner_x(num_cols - 1) + @name_width + 6
    header = build_header(lb_rounds, matches, num_cols)

    rows =
      Enum.map(0..(total_height - 1), fn r ->
        Enum.map(0..(total_width - 1), fn c -> Map.get(grid, {r, c}, ?\s) end)
        |> List.to_string()
        |> String.trim_trailing()
      end)

    ["Losers Bracket", header, "" | rows] |> Enum.join("\n")
  end

  defp build_lb_col_map(lb_rounds) do
    lb_rounds
    |> Enum.with_index()
    |> Enum.flat_map(fn {ids, col_idx} -> Enum.map(ids, &{&1, col_idx}) end)
    |> Map.new()
  end

  # Recursively computes row positions for each LB match from the LB final backward.
  # Returns {positions_map, total_height} where positions_map is %{match_id => {j, p1_row, p2_row}}.
  defp compute_lb_tree(match_id, matches, lb_col_map, row_offset) do
    match = matches[match_id]

    p1_in_lb =
      !!(match && match.p1_prereq_match && Map.has_key?(lb_col_map, match.p1_prereq_match))

    p2_in_lb =
      !!(match && match.p2_prereq_match && Map.has_key?(lb_col_map, match.p2_prereq_match))

    case {p1_in_lb, p2_in_lb} do
      {false, false} ->
        j = row_offset + 1
        {%{match_id => {j, row_offset, row_offset + 2}}, 3}

      {true, false} ->
        {p1_pos, p1_height} =
          compute_lb_tree(match.p1_prereq_match, matches, lb_col_map, row_offset)

        {p1_j, _, _} = p1_pos[match.p1_prereq_match]
        p2_row = row_offset + p1_height + 1
        j = div(p1_j + p2_row, 2)
        pos = Map.put(p1_pos, match_id, {j, p1_j, p2_row})
        {pos, p1_height + 2}

      {false, true} ->
        {p2_pos, p2_height} =
          compute_lb_tree(match.p2_prereq_match, matches, lb_col_map, row_offset + 2)

        {p2_j, _, _} = p2_pos[match.p2_prereq_match]
        p1_row = row_offset
        j = div(p1_row + p2_j, 2)
        pos = Map.put(p2_pos, match_id, {j, p1_row, p2_j})
        {pos, p2_height + 2}

      {true, true} ->
        {p1_pos, p1_height} =
          compute_lb_tree(match.p1_prereq_match, matches, lb_col_map, row_offset)

        {p1_j, _, _} = p1_pos[match.p1_prereq_match]

        {p2_pos, p2_height} =
          compute_lb_tree(match.p2_prereq_match, matches, lb_col_map, row_offset + p1_height + 1)

        {p2_j, _, _} = p2_pos[match.p2_prereq_match]
        j = div(p1_j + p2_j, 2)
        pos = Map.merge(p1_pos, p2_pos) |> Map.put(match_id, {j, p1_j, p2_j})
        {pos, p1_height + 1 + p2_height}
    end
  end

  defp draw_lb_structure(grid, match, col_idx, j, p1_row, p2_row, lb_col_map, participants) do
    p1_in_lb = !!(match.p1_prereq_match && Map.has_key?(lb_col_map, match.p1_prereq_match))
    p2_in_lb = !!(match.p2_prereq_match && Map.has_key?(lb_col_map, match.p2_prereq_match))
    cx = corner_x(col_idx)

    case {p1_in_lb, p2_in_lb} do
      {false, false} ->
        if col_idx == 0 do
          grid
          |> put_str(p1_row, 0, pad(name_label(match.p1_id, participants)) <> " ──┐")
          |> put_char(j, cx, ?├)
          |> put_str(p2_row, 0, pad(name_label(match.p2_id, participants)) <> " ──┘")
        else
          prev_cx = corner_x(col_idx - 1)

          grid
          |> put_str(
            p1_row,
            prev_cx + 1,
            wide_entry_str(name_label(match.p1_id, participants), :top)
          )
          |> put_char(j, cx, ?├)
          |> put_str(
            p2_row,
            prev_cx + 1,
            wide_entry_str(name_label(match.p2_id, participants), :bottom)
          )
        end

      {true, false} ->
        prev_cx = corner_x(col_idx - 1)

        grid =
          Enum.reduce((prev_cx + 1)..(cx - 1), grid, fn x, g ->
            put_char(g, p1_row, x, ?─)
          end)

        grid =
          put_str(
            grid,
            p2_row,
            prev_cx + 1,
            wide_entry_str(name_label(match.p2_id, participants), :bottom)
          )

        Enum.reduce(p1_row..p2_row, grid, fn row, g ->
          char =
            cond do
              row == p1_row -> ?┐
              row == j -> ?├
              row == p2_row -> ?┘
              true -> ?│
            end

          put_char(g, row, cx, char)
        end)

      {false, true} ->
        prev_cx = corner_x(col_idx - 1)

        grid =
          Enum.reduce((prev_cx + 1)..(cx - 1), grid, fn x, g ->
            put_char(g, p2_row, x, ?─)
          end)

        grid =
          put_str(
            grid,
            p1_row,
            prev_cx + 1,
            wide_entry_str(name_label(match.p1_id, participants), :top)
          )

        Enum.reduce(p1_row..p2_row, grid, fn row, g ->
          char =
            cond do
              row == p1_row -> ?┐
              row == j -> ?├
              row == p2_row -> ?┘
              true -> ?│
            end

          put_char(g, row, cx, char)
        end)

      {true, true} ->
        prev_cx = corner_x(col_idx - 1)

        grid =
          Enum.reduce((prev_cx + 1)..(cx - 1), grid, fn x, g ->
            g |> put_char(p1_row, x, ?─) |> put_char(p2_row, x, ?─)
          end)

        Enum.reduce(p1_row..p2_row, grid, fn row, g ->
          char =
            cond do
              row == p1_row -> ?┐
              row == j -> ?├
              row == p2_row -> ?┘
              true -> ?│
            end

          put_char(g, row, cx, char)
        end)
    end
  end

  defp draw_lb_winner_names(
         grid,
         match,
         col_idx,
         j,
         p1_row,
         p2_row,
         lb_col_map,
         matches,
         participants,
         num_cols
       ) do
    p1_in_lb = !!(match.p1_prereq_match && Map.has_key?(lb_col_map, match.p1_prereq_match))
    p2_in_lb = !!(match.p2_prereq_match && Map.has_key?(lb_col_map, match.p2_prereq_match))
    is_last = col_idx == num_cols - 1
    cx = corner_x(col_idx)
    winner = winner_label(match, participants)
    corner = winner_corner(match)

    case {p1_in_lb, p2_in_lb} do
      {false, false} ->
        write_winner_or_connector(grid, winner, corner, is_last, j, cx)

      {true, false} ->
        prev_cx = corner_x(col_idx - 1)
        p1_feeder = matches[match.p1_prereq_match]
        w1 = winner_label(p1_feeder, participants)
        grid = put_str(grid, p1_row, prev_cx + 1, connector_str(w1, :top))
        write_winner_or_connector(grid, winner, corner, is_last, j, cx)

      {false, true} ->
        prev_cx = corner_x(col_idx - 1)
        p2_feeder = matches[match.p2_prereq_match]
        w2 = winner_label(p2_feeder, participants)
        grid = put_str(grid, p2_row, prev_cx + 1, connector_str(w2, :bottom))
        write_winner_or_connector(grid, winner, corner, is_last, j, cx)

      {true, true} ->
        prev_cx = corner_x(col_idx - 1)
        p1_feeder = matches[match.p1_prereq_match]
        p2_feeder = matches[match.p2_prereq_match]
        w1 = winner_label(p1_feeder, participants)
        w2 = winner_label(p2_feeder, participants)
        grid = put_str(grid, p1_row, prev_cx + 1, connector_str(w1, :top))
        grid = put_str(grid, p2_row, prev_cx + 1, connector_str(w2, :bottom))
        write_winner_or_connector(grid, winner, corner, is_last, j, cx)
    end
  end

  defp write_winner_or_connector(grid, winner, _corner, true, j, cx) do
    put_str(grid, j, cx + 1, "── " <> truncate(winner))
  end

  defp write_winner_or_connector(grid, winner, corner, false, j, cx) do
    put_str(grid, j, cx + 1, connector_str(winner, corner))
  end

  defp winner_corner(%Match{winner_feeds: {_, :p1}}), do: :top
  defp winner_corner(%Match{winner_feeds: {_, :p2}}), do: :bottom
  defp winner_corner(_), do: :top

  # wide_entry_str builds a 19-char standalone name entry for LB drop-in slots (col_idx > 0).
  # Format: pad(name) <> " " <> "─────" <> corner = 12 + 1 + 5 + 1 = 19 chars.
  defp wide_entry_str(name, corner_type) do
    corner = if corner_type == :top, do: "┐", else: "┘"
    pad(name) <> " " <> String.duplicate("─", 5) <> corner
  end

  defp lb_final_winner(gf_match, matches, participants) do
    lb_final = gf_match && matches[gf_match.p2_prereq_match]
    winner_label(lb_final, participants)
  end

  defp loser_label(nil, _participants), do: "?"
  defp loser_label(%Match{loser_id: nil}, _participants), do: "?"
  defp loser_label(%Match{loser_id: id}, participants), do: name_label(id, participants)

  # =========================================================
  # Shared bracket drawing helpers
  # =========================================================

  defp corner_x(col_idx) do
    @name_width + 3 + col_idx * (@name_width + 7)
  end

  defp j_row(col_idx, match_idx) do
    trunc((4 * match_idx + 2) * :math.pow(2, col_idx)) - 1
  end

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

    grid = put_str(grid, p1_j, prev_cx + 1, connector_str(w1, :top))
    grid = put_str(grid, p2_j, prev_cx + 1, connector_str(w2, :bottom))

    if is_last do
      put_str(grid, j, cx + 1, "── " <> truncate(w))
    else
      corner = if rem(match_idx, 2) == 0, do: :top, else: :bottom
      put_str(grid, j, cx + 1, connector_str(w, corner))
    end
  end

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

  # =========================================================
  # Standings table rendering
  # =========================================================

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
