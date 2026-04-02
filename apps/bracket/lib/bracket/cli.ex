defmodule Bracket.CLI do
  @moduledoc false

  @usage """
  Usage: bracket <command> [options]

  Commands:
    new <name> --format <format> [--best-of <n>] [--dir <path>]
        Create a new tournament. Formats: single_elimination, double_elimination,
        round_robin, swiss. Saves to <name>.toml.

    add <name> <participant> [<participant> ...] [--dir <path>]
        Add one or more participants to a pending tournament.

    start <name> [--seeding random|standard] [--dir <path>]
        Seed and start the tournament, generating the first round of matches.

    report <name> --match <id> --score <p1>-<p2> [--dir <path>]
        Report a single-set score for a match.

    next-round <name> [--dir <path>]
        Generate the next Swiss round (Swiss format only).

    show <name> [--dir <path>]
        Display the current bracket state as ASCII art.

    standings <name> [--dir <path>]
        Display the current standings.

    matches <name> [--dir <path>]
        List all ready matches.

  Options:
    --dir <path>   Directory for .toml files (default: current directory)
  """

  def main(args) do
    case parse_args(args) do
      {:ok, command, opts} -> run(command, opts)
      {:error, message} -> die(message)
    end
  end

  defp run(:new, opts) do
    name = opts[:name]
    format = parse_format(opts[:format])
    best_of = String.to_integer(opts[:best_of] || "1")

    tournament = Bracket.new(name, format, config: [best_of: best_of])
    save(tournament, opts[:dir])
    IO.puts("Created tournament '#{name}' (#{format}).")
  end

  defp run(:add, opts) do
    tournament = load!(opts[:name], opts[:dir])
    participants = opts[:participants]

    tournament = Bracket.add_participants(tournament, participants)
    save(tournament, opts[:dir])
    IO.puts("Added #{length(participants)} participant(s) to '#{tournament.name}'.")
  end

  defp run(:start, opts) do
    tournament = load!(opts[:name], opts[:dir])
    seeding = parse_seeding(opts[:seeding] || "standard")

    case Bracket.start(tournament, seeding) do
      {:ok, tournament} ->
        save(tournament, opts[:dir])

        IO.puts(
          "Started '#{tournament.name}'. #{length(Bracket.next_matches(tournament))} match(es) ready."
        )

      {:error, reason} ->
        die("Failed to start: #{format_error(reason)}")
    end
  end

  defp run(:report, opts) do
    tournament = load!(opts[:name], opts[:dir])
    match_id = opts[:match]
    {p1, p2} = parse_score(opts[:score])

    case Bracket.report_score(tournament, match_id, p1, p2) do
      {:ok, tournament} ->
        save(tournament, opts[:dir])
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
    tournament = load!(opts[:name], opts[:dir])

    case Bracket.next_round(tournament) do
      {:ok, tournament} ->
        save(tournament, opts[:dir])
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
    tournament = load!(opts[:name], opts[:dir])
    IO.puts(Bracket.to_ascii(tournament))
  end

  defp run(:standings, opts) do
    tournament = load!(opts[:name], opts[:dir])
    print_standings(tournament)
  end

  defp run(:matches, opts) do
    tournament = load!(opts[:name], opts[:dir])
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

  defp run(:help, _opts) do
    IO.puts(@usage)
  end

  defp print_standings(tournament) do
    standings = Bracket.standings(tournament)
    participants = Map.new(tournament.participants, &{&1.id, &1})

    IO.puts("\nStandings:")
    IO.puts("  #  Name                W   L   D")
    IO.puts("  " <> String.duplicate("-", 36))

    Enum.each(standings, fn s ->
      p = Map.get(participants, s.participant_id)
      name = if p, do: p.name, else: s.participant_id

      IO.puts(
        "  #{String.pad_leading("#{s.rank}", 2)}. #{String.pad_trailing(name, 18)} #{String.pad_leading("#{s.wins}", 2)}  #{String.pad_leading("#{s.losses}", 2)}  #{String.pad_leading("#{s.draws}", 2)}"
      )
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

  defp load!(name, dir) do
    path = toml_path(name, dir)

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

  defp save(tournament, dir) do
    path = toml_path(tournament.name, dir)

    case File.write(path, Bracket.to_toml(tournament)) do
      :ok -> :ok
      {:error, reason} -> die("Failed to save #{path}: #{inspect(reason)}")
    end
  end

  defp toml_path(name, dir) do
    filename = name |> String.downcase() |> String.replace(~r/[^\w-]/, "_") |> Kernel.<>(".toml")
    base = dir || "."
    Path.join(base, filename)
  end

  defp parse_args(["new", name | rest]) do
    opts = parse_opts(rest)
    {:ok, :new, Map.put(opts, :name, name)}
  end

  defp parse_args(["add", name | rest]) do
    {flags, participants} = Enum.split_with(rest, fn arg -> String.starts_with?(arg, "--") end)
    opts = parse_opts(flags)
    {:ok, :add, opts |> Map.put(:name, name) |> Map.put(:participants, participants)}
  end

  defp parse_args(["start", name | rest]) do
    opts = parse_opts(rest)
    {:ok, :start, Map.put(opts, :name, name)}
  end

  defp parse_args(["report", name | rest]) do
    opts = parse_opts(rest)
    {:ok, :report, Map.put(opts, :name, name)}
  end

  defp parse_args(["next-round", name | rest]) do
    opts = parse_opts(rest)
    {:ok, :"next-round", Map.put(opts, :name, name)}
  end

  defp parse_args(["show", name | rest]) do
    opts = parse_opts(rest)
    {:ok, :show, Map.put(opts, :name, name)}
  end

  defp parse_args(["standings", name | rest]) do
    opts = parse_opts(rest)
    {:ok, :standings, Map.put(opts, :name, name)}
  end

  defp parse_args(["matches", name | rest]) do
    opts = parse_opts(rest)
    {:ok, :matches, Map.put(opts, :name, name)}
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

  defp parse_format(nil),
    do:
      die(
        "--format is required. Options: single_elimination, double_elimination, round_robin, swiss"
      )

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
