defmodule Bracket.Render.ASCII do
  @moduledoc false

  alias Bracket.{Match, Tournament}

  @match_width 20
  @padding 4

  @spec render(Tournament.t()) :: binary()
  def render(%Tournament{format: f} = tournament)
      when f in [:single_elimination, :double_elimination] do
    render_elimination(tournament)
  end

  def render(%Tournament{} = tournament) do
    render_standings_table(tournament)
  end

  defp render_elimination(%Tournament{} = tournament) do
    rounds = tournament.rounds
    participants_by_id = Map.new(tournament.participants, &{&1.id, &1})

    if rounds == [] do
      "(no matches generated)"
    else
      col_width = @match_width + @padding

      header = build_header(rounds, tournament.matches, col_width)
      grid = build_grid(rounds, tournament.matches, participants_by_id, col_width)

      [header, "" | grid]
      |> Enum.join("\n")
    end
  end

  defp build_header(rounds, matches, col_width) do
    rounds
    |> Enum.map(fn round_ids ->
      round = matches[List.first(round_ids)]
      label = round_label(round)
      String.pad_trailing(label, col_width)
    end)
    |> Enum.join("")
    |> String.trim_trailing()
  end

  defp round_label(%Match{round: r}) when r > 0 do
    "Round #{r}"
  end

  defp round_label(%Match{round: r}) when r < 0 do
    "LB Round #{abs(r)}"
  end

  defp round_label(%Match{id: "gf"}), do: "Grand Finals"
  defp round_label(%Match{id: "gf_reset"}), do: "GF Reset"
  defp round_label(%Match{id: "3rd"}), do: "3rd Place"
  defp round_label(_), do: "Finals"

  defp build_grid(rounds, matches, participants_by_id, col_width) do
    first_round_ids = List.first(rounds)
    row_count = length(first_round_ids) * 2

    0..(row_count - 1)
    |> Enum.map(fn row ->
      rounds
      |> Enum.with_index()
      |> Enum.map(fn {round_ids, col_idx} ->
        match_height = round_height(col_idx)
        match_idx = div(row, match_height)
        inner_row = rem(row, match_height)

        match_id = Enum.at(round_ids, match_idx)
        match = if match_id, do: matches[match_id]

        render_match_row(match, inner_row, match_height, col_width, participants_by_id)
      end)
      |> Enum.join("")
      |> String.trim_trailing()
    end)
    |> Enum.reject(&(&1 == ""))
  end

  defp round_height(col_idx) do
    trunc(:math.pow(2, col_idx + 1))
  end

  defp render_match_row(nil, _row, _height, col_width, _participants) do
    String.duplicate(" ", col_width)
  end

  defp render_match_row(match, row, height, col_width, participants) do
    mid = div(height, 2)
    top_mid = div(height, 4)
    bot_mid = div(3 * height, 4)

    cond do
      row == top_mid - 1 ->
        name = participant_display(match.p1_id, match, participants)
        format_name_row(name, col_width, :top)

      row == bot_mid - 1 ->
        name = participant_display(match.p2_id, match, participants)
        format_name_row(name, col_width, :bottom)

      row == top_mid ->
        format_connector_row(col_width, :top)

      row == bot_mid ->
        format_connector_row(col_width, :bottom)

      row == mid - 1 ->
        format_mid_row(col_width)

      true ->
        String.duplicate(" ", col_width)
    end
  end

  defp participant_display(nil, _match, _participants), do: "TBD"

  defp participant_display(id, match, participants) do
    case Map.get(participants, id) do
      nil ->
        "TBD"

      p ->
        seed = if p.seed, do: "(#{p.seed}) ", else: ""
        winner_marker = if match.winner_id == id, do: " *", else: ""
        "#{seed}#{p.name}#{winner_marker}"
    end
  end

  defp format_name_row(name, col_width, _side) do
    line_width = col_width - 4
    name = String.slice(name, 0, line_width)
    padded = String.pad_trailing(name, line_width)
    (padded <> " ──┐") |> String.pad_trailing(col_width)
  end

  defp format_connector_row(col_width, :top) do
    (String.pad_trailing("", col_width - 4) <> "    ")
    |> String.pad_trailing(col_width)

    String.duplicate(" ", col_width - 4) <> "   │"
  end

  defp format_connector_row(col_width, :bottom) do
    String.duplicate(" ", col_width - 4) <> "   │"
  end

  defp format_mid_row(col_width) do
    (String.duplicate(" ", col_width - 4) <> "───┤") |> String.pad_trailing(col_width)
  end

  defp render_standings_table(%Tournament{} = tournament) do
    standings = Bracket.Format.SingleElimination.standings(tournament)
    participants_by_id = Map.new(tournament.participants, &{&1.id, &1})

    name_width =
      standings
      |> Enum.map(fn s ->
        p = Map.get(participants_by_id, s.participant_id)
        if p, do: String.length(p.name), else: 3
      end)
      |> Enum.max(fn -> 10 end)
      |> max(10)

    header = standings_header(name_width)
    sep = standings_separator(name_width)
    rows = Enum.map(standings, &standings_row(&1, participants_by_id, name_width))

    ([sep, header, sep] ++ rows ++ [sep])
    |> Enum.join("\n")
  end

  defp standings_header(name_width) do
    "│ #  │ #{String.pad_trailing("Name", name_width)} │ W │ L │ D │  GD │"
  end

  defp standings_separator(name_width) do
    "├────┼─#{String.duplicate("─", name_width)}─┼───┼───┼───┼─────┤"
    |> String.replace("├", "┌", global: false)
    |> String.replace("┤", "┐", global: false)
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
