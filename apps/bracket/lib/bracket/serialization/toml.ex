defmodule Bracket.Serialization.TOML do
  @moduledoc false

  alias Bracket.{Config, Match, Participant, Score, Tournament}

  @version 1

  @spec encode(Tournament.t()) :: binary()
  def encode(%Tournament{} = tournament) do
    lines = []

    lines = lines ++ ["version = #{@version}", ""]
    lines = lines ++ encode_scalars(tournament)
    lines = lines ++ [""] ++ encode_rounds(tournament.rounds)
    lines = lines ++ encode_seeding(tournament.seeding)
    lines = lines ++ [""] ++ encode_config(tournament.config)
    lines = lines ++ [""] ++ encode_participants(tournament.participants)
    lines = lines ++ [""] ++ encode_matches(tournament.matches, tournament.rounds)

    Enum.join(lines, "\n") <> "\n"
  end

  defp encode_scalars(t) do
    [
      ~s(id = "#{t.id}"),
      ~s(name = #{toml_string(t.name)}),
      ~s(format = "#{t.format}"),
      ~s(status = "#{t.status}"),
      ~s(created_at = "#{DateTime.to_iso8601(t.created_at)}"),
      ~s(updated_at = "#{DateTime.to_iso8601(t.updated_at)}")
    ]
  end

  defp encode_config(%Config{} = config) do
    lines = ["[config]"]

    fields = [
      {"best_of", config.best_of},
      {"third_place_match", config.third_place_match},
      {"grand_finals_modifier", ~s("#{config.grand_finals_modifier}")},
      {"swiss_rounds", config.swiss_rounds},
      {"swiss_system", ~s("#{config.swiss_system}")},
      {"allow_draws", config.allow_draws},
      {"tiebreakers", encode_string_list(config.tiebreakers)}
    ]

    Enum.reduce(fields, lines, fn {k, v}, acc ->
      if v != nil do
        acc ++ ["#{k} = #{v}"]
      else
        acc
      end
    end)
  end

  defp encode_participants(participants) do
    Enum.flat_map(participants, fn p ->
      lines = ["[[participants]]"]
      lines = lines ++ [~s(id = "#{p.id}")]
      lines = lines ++ [~s(name = #{toml_string(p.name)})]
      if p.seed, do: lines ++ ["seed = #{p.seed}"], else: lines
    end)
  end

  defp encode_matches(matches, rounds) do
    ordered_ids = List.flatten(rounds)

    ordered_ids
    |> Enum.flat_map(fn id ->
      case Map.get(matches, id) do
        nil -> []
        match -> encode_match(match)
      end
    end)
  end

  defp encode_match(%Match{} = m) do
    lines = ["[[matches]]"]
    lines = lines ++ [~s(id = "#{m.id}")]
    lines = lines ++ ["round = #{m.round}"]
    lines = lines ++ ["position = #{m.position}"]
    lines = lines ++ ["status = \"#{m.status}\""]

    lines = if m.p1_id, do: lines ++ [~s(p1_id = "#{m.p1_id}")], else: lines
    lines = if m.p2_id, do: lines ++ [~s(p2_id = "#{m.p2_id}")], else: lines
    lines = if m.winner_id, do: lines ++ [~s(winner_id = "#{m.winner_id}")], else: lines
    lines = if m.loser_id, do: lines ++ [~s(loser_id = "#{m.loser_id}")], else: lines

    lines =
      if m.p1_prereq_match,
        do: lines ++ [~s(p1_prereq_match = "#{m.p1_prereq_match}")],
        else: lines

    lines =
      if m.p2_prereq_match,
        do: lines ++ [~s(p2_prereq_match = "#{m.p2_prereq_match}")],
        else: lines

    lines =
      if m.winner_feeds do
        {feed_id, slot} = m.winner_feeds
        lines ++ [~s(winner_feeds = ["#{feed_id}", "#{slot}"])]
      else
        lines
      end

    lines =
      if m.loser_feeds do
        {feed_id, slot} = m.loser_feeds
        lines ++ [~s(loser_feeds = ["#{feed_id}", "#{slot}"])]
      else
        lines
      end

    lines =
      if m.score do
        sets_str = encode_sets(m.score.sets)
        lines ++ ["sets = #{sets_str}"]
      else
        lines
      end

    lines ++ [""]
  end

  defp encode_sets(sets) do
    inner = Enum.map(sets, fn {p1, p2} -> "[#{p1}, #{p2}]" end)
    "[#{Enum.join(inner, ", ")}]"
  end

  defp encode_rounds(rounds) do
    rounds_str =
      rounds
      |> Enum.map(fn round ->
        ids = Enum.map(round, &~s("#{&1}"))
        "[#{Enum.join(ids, ", ")}]"
      end)
      |> Enum.join(", ")

    ["rounds = [#{rounds_str}]"]
  end

  defp encode_seeding([]), do: []

  defp encode_seeding(seeding) do
    ids = Enum.map(seeding, &~s("#{&1}"))
    ["", "seeding = [#{Enum.join(ids, ", ")}]"]
  end

  defp encode_string_list(list) do
    items = Enum.map(list, &~s("#{&1}"))
    "[#{Enum.join(items, ", ")}]"
  end

  defp toml_string(str) do
    escaped = String.replace(str, "\"", "\\\"")
    ~s("#{escaped}")
  end

  @spec decode(binary()) :: {:ok, Tournament.t()} | {:error, term()}
  def decode(toml) do
    with {:ok, data} <- Toml.decode(toml) do
      parse_tournament(data)
    end
  end

  @spec decode!(binary()) :: Tournament.t()
  def decode!(toml) do
    case decode(toml) do
      {:ok, tournament} ->
        tournament

      {:error, reason} ->
        raise ArgumentError, "Failed to decode tournament TOML: #{inspect(reason)}"
    end
  end

  defp parse_tournament(data) do
    with {:ok, id} <- fetch(data, "id"),
         {:ok, name} <- fetch(data, "name"),
         {:ok, format_str} <- fetch(data, "format"),
         {:ok, format} <-
           parse_atom(format_str, [:single_elimination, :double_elimination, :round_robin, :swiss]),
         {:ok, status_str} <- fetch(data, "status"),
         {:ok, status} <- parse_atom(status_str, [:pending, :in_progress, :complete]),
         {:ok, config} <- parse_config(Map.get(data, "config", %{})),
         {:ok, participants} <- parse_participants(Map.get(data, "participants", [])),
         {:ok, matches} <- parse_matches(Map.get(data, "matches", [])),
         {:ok, rounds} <- {:ok, parse_rounds(Map.get(data, "rounds", []))},
         {:ok, seeding} <- {:ok, Map.get(data, "seeding", [])},
         {:ok, created_at} <- parse_datetime(Map.get(data, "created_at")),
         {:ok, updated_at} <- parse_datetime(Map.get(data, "updated_at")) do
      tournament = %Tournament{
        id: id,
        name: name,
        format: format,
        status: status,
        config: config,
        participants: participants,
        matches: matches,
        rounds: rounds,
        seeding: seeding,
        created_at: created_at,
        updated_at: updated_at
      }

      {:ok, tournament}
    end
  end

  defp parse_config(data) do
    config = %Config{
      best_of: Map.get(data, "best_of", 1),
      third_place_match: Map.get(data, "third_place_match", false),
      grand_finals_modifier: parse_atom!(Map.get(data, "grand_finals_modifier", "standard")),
      swiss_rounds: Map.get(data, "swiss_rounds"),
      swiss_system: parse_atom!(Map.get(data, "swiss_system", "monrad")),
      tiebreakers: parse_atom_list(Map.get(data, "tiebreakers", ["buchholz", "wins"])),
      allow_draws: Map.get(data, "allow_draws", false)
    }

    {:ok, config}
  end

  defp parse_participants(list) do
    participants =
      Enum.map(list, fn p ->
        %Participant{
          id: Map.fetch!(p, "id"),
          name: Map.fetch!(p, "name"),
          seed: Map.get(p, "seed"),
          metadata: Map.get(p, "metadata", %{})
        }
      end)

    {:ok, participants}
  end

  defp parse_matches(list) do
    matches =
      list
      |> Enum.map(fn m ->
        score = parse_score(Map.get(m, "sets"))
        winner_feeds = parse_feed(Map.get(m, "winner_feeds"))
        loser_feeds = parse_feed(Map.get(m, "loser_feeds"))

        match = %Match{
          id: Map.fetch!(m, "id"),
          round: Map.fetch!(m, "round"),
          position: Map.fetch!(m, "position"),
          status: parse_atom!(Map.get(m, "status", "pending")),
          p1_id: Map.get(m, "p1_id"),
          p2_id: Map.get(m, "p2_id"),
          winner_id: Map.get(m, "winner_id"),
          loser_id: Map.get(m, "loser_id"),
          p1_prereq_match: Map.get(m, "p1_prereq_match"),
          p2_prereq_match: Map.get(m, "p2_prereq_match"),
          winner_feeds: winner_feeds,
          loser_feeds: loser_feeds,
          score: score
        }

        {match.id, match}
      end)
      |> Map.new()

    {:ok, matches}
  end

  defp parse_score(nil), do: nil

  defp parse_score(sets) do
    parsed_sets = Enum.map(sets, fn [p1, p2] -> {p1, p2} end)
    %Score{sets: parsed_sets}
  end

  defp parse_feed(nil), do: nil
  defp parse_feed([id, slot_str]), do: {id, parse_atom!(slot_str)}

  defp parse_rounds(rounds) do
    Enum.map(rounds, fn round -> round end)
  end

  defp parse_datetime(nil), do: {:ok, DateTime.utc_now()}

  defp parse_datetime(str) when is_binary(str) do
    case DateTime.from_iso8601(str) do
      {:ok, dt, _} -> {:ok, dt}
      {:error, reason} -> {:error, {:invalid_datetime, reason}}
    end
  end

  defp fetch(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> {:ok, value}
      :error -> {:error, {:missing_key, key}}
    end
  end

  defp parse_atom(str, allowed) do
    atom = String.to_existing_atom(str)

    if atom in allowed do
      {:ok, atom}
    else
      {:error, {:invalid_value, str}}
    end
  rescue
    ArgumentError -> {:error, {:unknown_atom, str}}
  end

  defp parse_atom!(str) do
    String.to_existing_atom(str)
  rescue
    ArgumentError -> String.to_atom(str)
  end

  defp parse_atom_list(list) do
    Enum.map(list, &parse_atom!/1)
  end
end
