defmodule Bracket.CLI do
  @moduledoc false

  @usage """
  Usage: bracket <command> <file.toml> [options]

  Commands:
    new <file.toml> <name> --format <format> [--best-of <n>]
        Create a new tournament. Formats: single_elimination, double_elimination,
        round_robin, swiss. Saves to <file.toml>.

    add <file.toml> <participant> [<participant> ...]
        Add one or more participants to a pending tournament.

    start <file.toml> [--seeding random|standard]
        Seed and start the tournament, generating the first round of matches.

    report <file.toml> --match <id> --score <p1>-<p2>
        Report a single-set score for a match.

    next-round <file.toml>
        Generate the next Swiss round (Swiss format only).

    show <file.toml>
        Display the current bracket state as ASCII art.

    standings <file.toml>
        Display the current standings.

    matches <file.toml>
        List all ready matches.

    reset <file.toml>
        Clear all matches and return the tournament to its starting state.

    image <file.toml> [--type svg|png] [--output <path>]
        Export bracket as an image (default: svg, saved alongside the .toml file).
  """

  def main(args) do
    case parse_args(args) do
      {:ok, command, opts} -> run(command, opts)
      {:error, message} -> die(message)
    end
  end

  defp run(:new, opts) do
    path = opts[:path]
    name = opts[:name]
    format = parse_format(opts[:format])
    best_of = String.to_integer(opts[:best_of] || "1")

    tournament = Bracket.new(name, format, config: [best_of: best_of])
    save!(tournament, path)
    IO.puts("Created tournament '#{name}' (#{format}). Saved to #{path}.")
  end

  defp run(:add, opts) do
    tournament = load!(opts[:path])
    participants = opts[:participants]

    tournament = Bracket.add_participants(tournament, participants)
    save!(tournament, opts[:path])
    IO.puts("Added #{length(participants)} participant(s) to '#{tournament.name}'.")
  end

  defp run(:start, opts) do
    tournament = load!(opts[:path])
    seeding = parse_seeding(opts[:seeding] || "standard")

    case Bracket.start(tournament, seeding) do
      {:ok, tournament} ->
        save!(tournament, opts[:path])

        IO.puts(
          "Started '#{tournament.name}'. #{length(Bracket.next_matches(tournament))} match(es) ready."
        )

      {:error, reason} ->
        die("Failed to start: #{format_error(reason)}")
    end
  end

  defp run(:report, opts) do
    tournament = load!(opts[:path])
    match_id = opts[:match]
    {p1, p2} = parse_score(opts[:score])

    case Bracket.report_score(tournament, match_id, p1, p2) do
      {:ok, tournament} ->
        save!(tournament, opts[:path])
        match = tournament.matches[match_id]
        winner = winner_name(tournament, match)
        IO.puts("Reported #{p1}-#{p2} for match #{match_id}. Winner: #{winner}.")

        if Bracket.complete?(tournament) do
          IO.puts("Tournament complete!")
          print_standings(tournament)
        end

      {:error, reason} ->
        die("Failed to report score: #{format_error(reason)}")
    end
  end

  defp run(:"next-round", opts) do
    tournament = load!(opts[:path])

    case Bracket.next_round(tournament) do
      {:ok, tournament} ->
        save!(tournament, opts[:path])
        round = length(tournament.rounds)

        IO.puts(
          "Generated round #{round}. #{length(Bracket.next_matches(tournament))} match(es) ready."
        )

      {:error, :tournament_complete} ->
        IO.puts("Tournament is complete.")

      {:error, reason} ->
        die("Failed to generate next round: #{format_error(reason)}")
    end
  end

  defp run(:show, opts) do
    tournament = load!(opts[:path])
    IO.puts(Bracket.to_ascii(tournament))
  end

  defp run(:standings, opts) do
    tournament = load!(opts[:path])
    print_standings(tournament)
  end

  defp run(:matches, opts) do
    tournament = load!(opts[:path])

    if Bracket.complete?(tournament) do
      IO.puts("Tournament is complete.")
      print_standings(tournament)
    else
      ready = Bracket.next_matches(tournament)

      if ready == [] do
        IO.puts("No matches ready.")
      else
        Enum.each(ready, fn m ->
          p1 = participant_name(tournament, m.p1_id)
          p2 = participant_name(tournament, m.p2_id)
          IO.puts("  #{m.id}: #{p1} vs #{p2}")
        end)
      end
    end
  end

  defp run(:reset, opts) do
    tournament = load!(opts[:path])
    tournament = Bracket.reset(tournament)
    save!(tournament, opts[:path])

    IO.puts(
      "Reset '#{tournament.name}'. #{length(tournament.participants)} participant(s) remain."
    )
  end

  defp run(:image, opts) do
    tournament = load!(opts[:path])
    type = opts[:type] || "svg"
    output = opts[:output] || default_image_path(opts[:path], type)

    case type do
      "svg" ->
        svg = Bracket.to_svg(tournament)
        write_file!(output, svg)
        IO.puts("Saved SVG to #{output}.")

      "png" ->
        case Bracket.to_png(tournament) do
          {:ok, png} ->
            write_file!(output, png)
            IO.puts("Saved PNG to #{output}.")

          {:error, :vix_not_available} ->
            die("PNG export requires the vix dependency. Install it and recompile.")

          {:error, reason} ->
            die("PNG export failed: #{inspect(reason)}")
        end

      other ->
        die("Unknown image type: #{other}. Use svg or png.")
    end
  end

  defp run(:help, _opts) do
    IO.puts(@usage)
  end

  defp default_image_path(toml_path, type) do
    base = Path.rootname(toml_path)
    "#{base}.#{type}"
  end

  defp print_standings(tournament) do
    standings = Bracket.standings(tournament)
    participants = Map.new(tournament.participants, &{&1.id, &1})

    name_width =
      standings
      |> Enum.map(fn s ->
        p = Map.get(participants, s.participant_id)
        name = if p, do: p.name, else: s.participant_id
        String.length(name)
      end)
      |> Enum.max(fn -> 10 end)
      |> max(10)

    IO.puts("\nStandings:")

    IO.puts(
      "  #{String.pad_trailing("#.", 4)} #{String.pad_trailing("Name", name_width)}  W    L    D"
    )

    IO.puts("  " <> String.duplicate("─", name_width + 20))

    Enum.each(standings, fn s ->
      p = Map.get(participants, s.participant_id)
      name = if p, do: p.name, else: s.participant_id

      rank = String.pad_trailing("#{s.rank}.", 4)
      name_col = String.pad_trailing(name, name_width)
      wins = String.pad_leading("#{s.wins}", 2)
      losses = String.pad_leading("#{s.losses}", 2)
      draws = String.pad_leading("#{s.draws}", 2)

      IO.puts("  #{rank} #{name_col}  #{wins}   #{losses}   #{draws}")
    end)
  end

  defp winner_name(tournament, %{winner_id: id}) when id != nil do
    participant_name(tournament, id)
  end

  defp winner_name(_tournament, _match), do: "(in progress)"

  defp participant_name(tournament, id) when id != nil do
    case Enum.find(tournament.participants, &(&1.id == id)) do
      nil -> id
      p -> p.name
    end
  end

  defp participant_name(_tournament, nil), do: "TBD"

  defp load!(path) do
    case File.read(path) do
      {:ok, content} ->
        case Bracket.from_toml(content) do
          {:ok, tournament} -> tournament
          {:error, reason} -> die("Failed to parse #{path}: #{inspect(reason)}")
        end

      {:error, :enoent} ->
        die("Tournament file not found: #{path}")

      {:error, reason} ->
        die("Failed to read #{path}: #{inspect(reason)}")
    end
  end

  defp save!(tournament, path) do
    case File.write(path, Bracket.to_toml(tournament)) do
      :ok -> :ok
      {:error, reason} -> die("Failed to save #{path}: #{inspect(reason)}")
    end
  end

  defp write_file!(path, content) do
    case File.write(path, content) do
      :ok -> :ok
      {:error, reason} -> die("Failed to write #{path}: #{inspect(reason)}")
    end
  end

  defp parse_args(["new", path, name | rest]) do
    opts = parse_opts(rest)
    {:ok, :new, opts |> Map.put(:path, path) |> Map.put(:name, name)}
  end

  defp parse_args(["add", path | rest]) do
    {flags, participants} = Enum.split_with(rest, &String.starts_with?(&1, "--"))
    opts = parse_opts(flags)
    {:ok, :add, opts |> Map.put(:path, path) |> Map.put(:participants, participants)}
  end

  defp parse_args(["start", path | rest]) do
    opts = parse_opts(rest)
    {:ok, :start, Map.put(opts, :path, path)}
  end

  defp parse_args(["report", path | rest]) do
    opts = parse_opts(rest)
    {:ok, :report, Map.put(opts, :path, path)}
  end

  defp parse_args(["next-round", path | rest]) do
    opts = parse_opts(rest)
    {:ok, :"next-round", Map.put(opts, :path, path)}
  end

  defp parse_args(["show", path | rest]) do
    opts = parse_opts(rest)
    {:ok, :show, Map.put(opts, :path, path)}
  end

  defp parse_args(["standings", path | rest]) do
    opts = parse_opts(rest)
    {:ok, :standings, Map.put(opts, :path, path)}
  end

  defp parse_args(["matches", path | rest]) do
    opts = parse_opts(rest)
    {:ok, :matches, Map.put(opts, :path, path)}
  end

  defp parse_args(["reset", path | rest]) do
    opts = parse_opts(rest)
    {:ok, :reset, Map.put(opts, :path, path)}
  end

  defp parse_args(["image", path | rest]) do
    opts = parse_opts(rest)
    {:ok, :image, Map.put(opts, :path, path)}
  end

  defp parse_args(["help" | _]), do: {:ok, :help, %{}}
  defp parse_args([]), do: {:ok, :help, %{}}

  defp parse_args([unknown | _]) do
    {:error, "Unknown command: #{unknown}. Run 'bracket help' for usage."}
  end

  defp parse_opts(args) do
    args
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.reduce(%{}, fn
      ["--" <> key, value], acc ->
        if String.starts_with?(value, "--") do
          acc
        else
          Map.put(acc, String.to_atom(key), value)
        end

      _, acc ->
        acc
    end)
  end

  defp parse_format(nil) do
    die(
      "--format is required. Options: single_elimination, double_elimination, round_robin, swiss"
    )
  end

  defp parse_format("single_elimination"), do: :single_elimination
  defp parse_format("double_elimination"), do: :double_elimination
  defp parse_format("round_robin"), do: :round_robin
  defp parse_format("swiss"), do: :swiss
  defp parse_format(f), do: die("Unknown format: #{f}")

  defp parse_seeding("random"), do: :random
  defp parse_seeding("standard"), do: :standard
  defp parse_seeding(nil), do: :standard
  defp parse_seeding(s), do: die("Unknown seeding: #{s}. Options: standard, random")

  defp parse_score(nil), do: die("--score is required, e.g. --score 3-1")

  defp parse_score(str) do
    case String.split(str, "-") do
      [p1, p2] -> {String.to_integer(p1), String.to_integer(p2)}
      _ -> die("Invalid score format: #{str}. Expected p1-p2, e.g. 3-1")
    end
  end

  defp format_error(:not_enough_participants), do: "not enough participants (need at least 2)"
  defp format_error({:match_not_ready, status}), do: "match is #{status}, not ready"
  defp format_error(:not_found), do: "match not found"
  defp format_error(:current_round_incomplete), do: "current round is not yet complete"
  defp format_error({:not_applicable, format}), do: "not applicable for #{format}"
  defp format_error(reason), do: inspect(reason)

  defp die(message) do
    IO.puts(:stderr, "Error: #{message}")
    System.halt(1)
  end
end
