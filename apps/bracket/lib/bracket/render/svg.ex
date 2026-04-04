defmodule Bracket.Render.SVG do
  @moduledoc false

  alias Bracket.Tournament

  @default_opts [
    background: "#FFFFFF",
    match_fill: "#F5F5F5",
    match_stroke: "#CCCCCC",
    winner_fill: "#D4EDDA",
    winner_stroke: "#28A745",
    text_color: "#333333",
    header_color: "#666666",
    connector_color: "#CCCCCC",
    font_family: "monospace",
    font_size: 13,
    match_width: 180,
    match_height: 44,
    h_gap: 60,
    v_gap: 10,
    padding: 24,
    header_height: 28
  ]

  @spec render(Tournament.t(), keyword()) :: binary()
  def render(tournament, opts \\ [])

  def render(%Tournament{format: f} = tournament, opts)
      when f in [:single_elimination, :double_elimination] do
    render_elimination(tournament, opts)
  end

  def render(%Tournament{} = tournament, opts) do
    render_standings(tournament, opts)
  end

  defp render_elimination(%Tournament{} = tournament, user_opts) do
    cfg = Keyword.merge(@default_opts, user_opts)

    rounds = tournament.rounds
    matches = tournament.matches
    participants = Map.new(tournament.participants, &{&1.id, &1})

    if rounds == [] do
      render_empty(cfg)
    else
      {width, height} = compute_dimensions(rounds, cfg)
      elements = build_elimination_elements(rounds, matches, participants, cfg)
      wrap_svg(elements, width, height, cfg[:background])
    end
  end

  defp render_standings(%Tournament{} = tournament, user_opts) do
    cfg = Keyword.merge(@default_opts, user_opts)
    standings = Bracket.standings(tournament)
    participants = Map.new(tournament.participants, &{&1.id, &1})

    rows = length(standings)
    col_widths = [32, 200, 48, 48, 48, 64]
    table_width = Enum.sum(col_widths) + cfg[:padding] * 2
    row_height = 32
    header_h = 40
    table_height = header_h + rows * row_height + cfg[:padding] * 2 + cfg[:header_height]

    elements =
      [render_title(tournament.name, cfg)] ++
        render_standings_table(standings, participants, col_widths, row_height, header_h, cfg)

    wrap_svg(elements, table_width, table_height, cfg[:background])
  end

  defp compute_dimensions(rounds, cfg) do
    num_rounds = length(rounds)
    first_round_count = rounds |> List.first([]) |> length()

    slot_height = cfg[:match_height] + cfg[:v_gap]
    total_slots = first_round_count * slot_height - cfg[:v_gap]
    height = total_slots + cfg[:padding] * 2 + cfg[:header_height]

    width =
      cfg[:padding] * 2 + num_rounds * cfg[:match_width] + (num_rounds - 1) * cfg[:h_gap]

    {width, height}
  end

  defp build_elimination_elements(rounds, matches, participants, cfg) do
    round_headers = render_round_headers(rounds, matches, cfg)
    match_elements = render_all_matches(rounds, matches, participants, cfg)
    connector_elements = render_all_connectors(rounds, matches, cfg)

    round_headers ++ connector_elements ++ match_elements
  end

  defp render_round_headers(rounds, matches, cfg) do
    rounds
    |> Enum.with_index()
    |> Enum.map(fn {round_ids, col_idx} ->
      x = match_x(col_idx, cfg)
      y = cfg[:padding] - 4
      label = round_label(matches[List.first(round_ids)], col_idx, length(rounds))

      ~s(<text x="#{x}" y="#{y}" font-family="#{cfg[:font_family]}" ) <>
        ~s(font-size="#{cfg[:font_size] - 1}" fill="#{cfg[:header_color]}" ) <>
        ~s(font-weight="bold">#{escape(label)}</text>)
    end)
  end

  defp render_all_matches(rounds, matches, participants, cfg) do
    Enum.flat_map(rounds |> Enum.with_index(), fn {round_ids, col_idx} ->
      Enum.flat_map(round_ids |> Enum.with_index(), fn {match_id, match_idx} ->
        match = matches[match_id]
        if match, do: render_match(match, col_idx, match_idx, participants, cfg), else: []
      end)
    end)
  end

  defp render_match(match, col_idx, match_idx, participants, cfg) do
    x = match_x(col_idx, cfg)
    y = match_y(col_idx, match_idx, cfg)
    w = cfg[:match_width]
    h = cfg[:match_height]
    half_h = div(h, 2)

    fill = if match.status == :complete, do: cfg[:match_fill], else: cfg[:match_fill]
    stroke = cfg[:match_stroke]

    p1_name = participant_label(match.p1_id, participants)
    p2_name = participant_label(match.p2_id, participants)

    p1_fill =
      if match.winner_id == match.p1_id and match.winner_id != nil,
        do: cfg[:winner_fill],
        else: "none"

    p2_fill =
      if match.winner_id == match.p2_id and match.winner_id != nil,
        do: cfg[:winner_fill],
        else: "none"

    p1_stroke =
      if match.winner_id == match.p1_id and match.winner_id != nil,
        do: cfg[:winner_stroke],
        else: stroke

    p2_stroke =
      if match.winner_id == match.p2_id and match.winner_id != nil,
        do: cfg[:winner_stroke],
        else: stroke

    font = cfg[:font_family]
    fs = cfg[:font_size]
    tc = cfg[:text_color]

    [
      # Outer box
      ~s(<rect x="#{x}" y="#{y}" width="#{w}" height="#{h}" ) <>
        ~s(fill="#{fill}" stroke="#{stroke}" stroke-width="1" rx="3"/>),
      # Divider line
      ~s(<line x1="#{x}" y1="#{y + half_h}" x2="#{x + w}" y2="#{y + half_h}" ) <>
        ~s(stroke="#{stroke}" stroke-width="1"/>),
      # P1 highlight
      if(p1_fill != "none",
        do:
          ~s(<rect x="#{x}" y="#{y}" width="#{w}" height="#{half_h}" ) <>
            ~s(fill="#{p1_fill}" stroke="#{p1_stroke}" stroke-width="1" rx="3"/>),
        else: ""
      ),
      # P2 highlight
      if(p2_fill != "none",
        do:
          ~s(<rect x="#{x}" y="#{y + half_h}" width="#{w}" height="#{half_h}" ) <>
            ~s(fill="#{p2_fill}" stroke="#{p2_stroke}" stroke-width="1" rx="3"/>),
        else: ""
      ),
      # P1 name
      ~s(<text x="#{x + 8}" y="#{y + half_h - 6}" font-family="#{font}" ) <>
        ~s(font-size="#{fs}" fill="#{tc}" dominant-baseline="middle">#{escape(p1_name)}</text>),
      # P2 name
      ~s(<text x="#{x + 8}" y="#{y + half_h + half_h - 6}" font-family="#{font}" ) <>
        ~s(font-size="#{fs}" fill="#{tc}" dominant-baseline="middle">#{escape(p2_name)}</text>)
    ]
    |> Enum.reject(&(&1 == ""))
  end

  defp render_all_connectors(rounds, matches, cfg) do
    Enum.flat_map(rounds |> Enum.with_index(), fn {round_ids, col_idx} ->
      Enum.flat_map(round_ids |> Enum.with_index(), fn {match_id, match_idx} ->
        match = matches[match_id]

        if match && match.winner_feeds do
          {target_id, slot} = match.winner_feeds

          target_idx =
            rounds
            |> Enum.with_index()
            |> Enum.find_value(fn {r_ids, _} ->
              if Enum.member?(r_ids, target_id) do
                r_idx = Enum.find_index(r_ids, &(&1 == target_id))
                r_idx
              end
            end)

          if target_idx != nil do
            target_col = col_idx + 1
            render_connector(col_idx, match_idx, target_col, target_idx, slot, cfg)
          else
            []
          end
        else
          []
        end
      end)
    end)
  end

  defp render_connector(from_col, from_idx, to_col, to_idx, slot, cfg) do
    from_x = match_x(from_col, cfg) + cfg[:match_width]
    from_y = match_center_y(from_col, from_idx, cfg)

    to_x = match_x(to_col, cfg)
    to_y = slot_y(slot, to_col, to_idx, cfg)

    mid_x = from_x + div(cfg[:h_gap], 2)
    color = cfg[:connector_color]

    [
      ~s(<line x1="#{from_x}" y1="#{from_y}" x2="#{mid_x}" y2="#{from_y}" ) <>
        ~s(stroke="#{color}" stroke-width="1.5"/>),
      ~s(<line x1="#{mid_x}" y1="#{from_y}" x2="#{mid_x}" y2="#{to_y}" ) <>
        ~s(stroke="#{color}" stroke-width="1.5"/>),
      ~s(<line x1="#{mid_x}" y1="#{to_y}" x2="#{to_x}" y2="#{to_y}" ) <>
        ~s(stroke="#{color}" stroke-width="1.5"/>)
    ]
  end

  defp render_standings_table(standings, participants, col_widths, row_height, header_h, cfg) do
    x0 = cfg[:padding]
    y0 = cfg[:padding] + cfg[:header_height]
    font = cfg[:font_family]
    fs = cfg[:font_size]
    tc = cfg[:text_color]

    headers = ["#", "Name", "W", "L", "D", "GD"]
    col_xs = col_x_positions(col_widths, x0)
    table_width = Enum.sum(col_widths)

    header_bg =
      ~s(<rect x="#{x0}" y="#{y0}" width="#{table_width}" height="#{header_h}" ) <>
        ~s(fill="#F0F0F0" stroke="#{cfg[:match_stroke]}" stroke-width="1"/>)

    header_texts =
      Enum.zip(headers, col_xs)
      |> Enum.map(fn {label, x} ->
        ~s(<text x="#{x + 8}" y="#{y0 + div(header_h, 2) + 5}" font-family="#{font}" ) <>
          ~s(font-size="#{fs}" fill="#{cfg[:header_color]}" font-weight="bold">#{escape(label)}</text>)
      end)

    row_elements =
      standings
      |> Enum.with_index()
      |> Enum.flat_map(fn {s, i} ->
        p = Map.get(participants, s.participant_id)
        name = if p, do: p.name, else: s.participant_id
        gd = s.game_wins - s.game_losses
        gd_str = if gd >= 0, do: "+#{gd}", else: "#{gd}"

        row_y = y0 + header_h + i * row_height
        row_bg_fill = if rem(i, 2) == 0, do: "#FFFFFF", else: "#FAFAFA"
        values = ["#{s.rank}", name, "#{s.wins}", "#{s.losses}", "#{s.draws}", gd_str]

        row_bg =
          ~s(<rect x="#{x0}" y="#{row_y}" width="#{table_width}" height="#{row_height}" ) <>
            ~s(fill="#{row_bg_fill}" stroke="#{cfg[:match_stroke]}" stroke-width="0.5"/>)

        texts =
          Enum.zip(values, col_xs)
          |> Enum.map(fn {val, x} ->
            ~s(<text x="#{x + 8}" y="#{row_y + div(row_height, 2) + 5}" font-family="#{font}" ) <>
              ~s(font-size="#{fs}" fill="#{tc}">#{escape(val)}</text>)
          end)

        [row_bg | texts]
      end)

    [header_bg | header_texts] ++ row_elements
  end

  defp render_title(name, cfg) do
    x = cfg[:padding]
    y = cfg[:padding] + cfg[:header_height] - 8

    ~s(<text x="#{x}" y="#{y}" font-family="#{cfg[:font_family]}" ) <>
      ~s(font-size="#{cfg[:font_size] + 2}" fill="#{cfg[:text_color]}" ) <>
      ~s(font-weight="bold">#{escape(name)}</text>)
  end

  defp render_empty(cfg) do
    wrap_svg(
      [
        ~s(<text x="20" y="40" font-family="#{cfg[:font_family]}" fill="#{cfg[:text_color]}">No matches generated</text>)
      ],
      200,
      60,
      cfg[:background]
    )
  end

  defp wrap_svg(elements, width, height, background) do
    body = Enum.join(elements, "\n  ")

    """
    <svg xmlns="http://www.w3.org/2000/svg" width="#{width}" height="#{height}" viewBox="0 0 #{width} #{height}">
      <rect width="#{width}" height="#{height}" fill="#{background}"/>
      #{body}
    </svg>
    """
  end

  defp match_x(col_idx, cfg) do
    cfg[:padding] + col_idx * (cfg[:match_width] + cfg[:h_gap])
  end

  defp match_y(col_idx, match_idx, cfg) do
    slot_h = slot_height(col_idx, cfg)
    top = cfg[:padding] + cfg[:header_height] + match_idx * slot_h
    top + div(slot_h - cfg[:match_height], 2)
  end

  defp match_center_y(col_idx, match_idx, cfg) do
    match_y(col_idx, match_idx, cfg) + div(cfg[:match_height], 2)
  end

  defp slot_y(:p1, col_idx, match_idx, cfg) do
    match_y(col_idx, match_idx, cfg) + div(cfg[:match_height], 4)
  end

  defp slot_y(:p2, col_idx, match_idx, cfg) do
    match_y(col_idx, match_idx, cfg) + div(cfg[:match_height] * 3, 4)
  end

  defp slot_height(col_idx, cfg) do
    (cfg[:match_height] + cfg[:v_gap]) * round(:math.pow(2, col_idx))
  end

  defp participant_label(nil, _participants), do: "TBD"

  defp participant_label(id, participants) do
    case Map.get(participants, id) do
      nil -> "TBD"
      p -> p.name
    end
  end

  defp round_label(_match, col_idx, total_rounds) do
    rounds_from_end = total_rounds - col_idx

    cond do
      rounds_from_end == 1 -> "Final"
      rounds_from_end == 2 -> "Semifinal"
      rounds_from_end == 3 -> "Quarterfinal"
      true -> "Round #{col_idx + 1}"
    end
  end

  defp col_x_positions(widths, x0) do
    Enum.scan(widths, x0, fn w, acc -> acc + w end)
    |> then(fn positions -> [x0 | Enum.drop(positions, -1)] end)
  end

  defp escape(str) do
    str
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
  end
end
