defmodule Bracket.Tournament do
  @moduledoc false

  alias Bracket.{Config, Match, Participant, Score}

  defstruct [
    :id,
    :name,
    :format,
    :created_at,
    :updated_at,
    status: :pending,
    config: %Config{},
    participants: [],
    matches: %{},
    rounds: [],
    seeding: [],
    metadata: %{}
  ]

  @type format() :: :single_elimination | :double_elimination | :round_robin | :swiss
  @type status() :: :pending | :in_progress | :complete

  @type t() :: %__MODULE__{
          id: binary(),
          name: binary(),
          format: format(),
          status: status(),
          config: Config.t(),
          participants: [Participant.t()],
          matches: %{binary() => Match.t()},
          rounds: [[binary()]],
          seeding: [binary()],
          metadata: map(),
          created_at: DateTime.t(),
          updated_at: DateTime.t()
        }

  @spec new(binary(), format(), keyword()) :: t()
  def new(name, format, opts \\ []) do
    now = DateTime.utc_now()

    %__MODULE__{
      id: opts[:id] || generate_id(),
      name: name,
      format: format,
      config: Config.new(opts[:config] || []),
      metadata: opts[:metadata] || %{},
      created_at: now,
      updated_at: now
    }
  end

  @spec add_participant(t(), binary(), keyword()) :: t()
  def add_participant(%__MODULE__{} = tournament, name, opts \\ []) do
    participant = Participant.new(name, opts)

    %{tournament | participants: tournament.participants ++ [participant]}
    |> touch()
  end

  @spec participant_count(t()) :: non_neg_integer()
  def participant_count(%__MODULE__{participants: ps}) do
    length(ps)
  end

  @spec get_participant(t(), binary()) :: Participant.t() | nil
  def get_participant(%__MODULE__{participants: ps}, id) do
    Enum.find(ps, &(&1.id == id))
  end

  @spec get_match(t(), binary()) :: {:ok, Match.t()} | {:error, :not_found}
  def get_match(%__MODULE__{matches: matches}, id) do
    case Map.fetch(matches, id) do
      {:ok, match} -> {:ok, match}
      :error -> {:error, :not_found}
    end
  end

  @spec put_match(t(), Match.t()) :: t()
  def put_match(%__MODULE__{matches: matches} = tournament, %Match{id: id} = match) do
    %{tournament | matches: Map.put(matches, id, match)}
    |> touch()
  end

  @spec next_matches(t()) :: [Match.t()]
  def next_matches(%__MODULE__{matches: matches}) do
    matches
    |> Map.values()
    |> Enum.filter(&(&1.status == :ready))
    |> Enum.sort_by(&{abs(&1.round), &1.position})
  end

  @spec complete?(t()) :: boolean()
  def complete?(%__MODULE__{status: :complete}), do: true
  def complete?(%__MODULE__{}), do: false

  @spec report_score(t(), binary(), Score.t()) :: {:ok, t()} | {:error, term()}
  def report_score(%__MODULE__{} = tournament, match_id, %Score{} = score) do
    with {:ok, match} <- get_match(tournament, match_id),
         :ok <- validate_match_ready(match) do
      best_of = tournament.config.best_of
      apply_score(tournament, match, score, best_of)
    end
  end

  defp validate_match_ready(%Match{status: :ready}), do: :ok
  defp validate_match_ready(%Match{status: :in_progress}), do: :ok
  defp validate_match_ready(%Match{status: status}), do: {:error, {:match_not_ready, status}}

  defp apply_score(tournament, match, score, best_of) do
    unless Score.complete?(score, best_of) do
      updated = %{match | score: score, status: :in_progress}
      {:ok, put_match(tournament, updated)}
    else
      winner_id = winner_participant_id(match, Score.winner(score))
      loser_id = loser_participant_id(match, Score.winner(score))

      completed = %{
        match
        | score: score,
          status: :complete,
          winner_id: winner_id,
          loser_id: loser_id
      }

      tournament
      |> put_match(completed)
      |> advance_match(completed)
      |> check_complete()
      |> then(&{:ok, &1})
    end
  end

  defp winner_participant_id(%Match{p1_id: p1}, :p1), do: p1
  defp winner_participant_id(%Match{p2_id: p2}, :p2), do: p2

  defp loser_participant_id(%Match{p2_id: p2}, :p1), do: p2
  defp loser_participant_id(%Match{p1_id: p1}, :p2), do: p1

  defp advance_match(tournament, %Match{winner_feeds: wf, loser_feeds: lf} = match) do
    tournament
    |> maybe_place_in_match(wf, match.winner_id)
    |> maybe_place_in_match(lf, match.loser_id)
  end

  defp maybe_place_in_match(tournament, nil, _participant_id), do: tournament

  defp maybe_place_in_match(tournament, {target_id, slot}, participant_id) do
    case get_match(tournament, target_id) do
      {:ok, target} ->
        updated = place_participant(target, slot, participant_id)

        cond do
          Match.ready?(updated) ->
            put_match(tournament, %{updated | status: :ready})

          bye_winner_id = bye_winner(updated) ->
            bye = %{updated | status: :bye, winner_id: bye_winner_id}

            tournament
            |> put_match(bye)
            |> advance_match(bye)

          true ->
            put_match(tournament, updated)
        end

      {:error, :not_found} ->
        tournament
    end
  end

  defp bye_winner(%Match{p1_id: p1, p2_id: nil, p2_prereq_match: nil}) when p1 != nil, do: p1
  defp bye_winner(%Match{p1_id: nil, p2_id: p2, p1_prereq_match: nil}) when p2 != nil, do: p2
  defp bye_winner(_), do: nil

  defp place_participant(match, :p1, id), do: %{match | p1_id: id}
  defp place_participant(match, :p2, id), do: %{match | p2_id: id}

  defp check_complete(%__MODULE__{format: format} = tournament) do
    module = format_module(format)

    if module.complete?(tournament) do
      %{tournament | status: :complete} |> touch()
    else
      tournament
    end
  end

  defp format_module(:single_elimination), do: Bracket.Format.SingleElimination
  defp format_module(:double_elimination), do: Bracket.Format.DoubleElimination
  defp format_module(:round_robin), do: Bracket.Format.RoundRobin
  defp format_module(:swiss), do: Bracket.Format.Swiss

  @spec touch(t()) :: t()
  def touch(tournament) do
    %{tournament | updated_at: DateTime.utc_now()}
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
