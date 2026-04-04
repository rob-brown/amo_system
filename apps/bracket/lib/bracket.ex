defmodule Bracket do
  @moduledoc false

  alias Bracket.{Format, Render, Score, Seeding, Serialization, Tournament}

  @type format() :: Tournament.format()
  @type seeding_strategy() :: Seeding.strategy()

  @spec new(binary(), format(), keyword()) :: Tournament.t()
  def new(name, format, opts \\ []) do
    Tournament.new(name, format, opts)
  end

  @spec add_participant(Tournament.t(), binary(), keyword()) :: Tournament.t()
  def add_participant(%Tournament{} = tournament, name, opts \\ []) do
    Tournament.add_participant(tournament, name, opts)
  end

  @spec add_participants(Tournament.t(), [binary() | keyword()]) :: Tournament.t()
  def add_participants(%Tournament{} = tournament, participants) do
    Enum.reduce(participants, tournament, fn
      name, t when is_binary(name) -> Tournament.add_participant(t, name)
      opts, t when is_list(opts) -> Tournament.add_participant(t, opts[:name], opts)
      %{name: name} = p, t -> Tournament.add_participant(t, name, Map.to_list(p))
    end)
  end

  @spec start(Tournament.t(), seeding_strategy()) :: {:ok, Tournament.t()} | {:error, term()}
  def start(%Tournament{} = tournament, seeding \\ :standard) do
    with :ok <- validate_min_participants(tournament) do
      tournament
      |> Seeding.apply(seeding)
      |> format_module(tournament.format).generate_matches()
    end
  end

  @spec start!(Tournament.t(), seeding_strategy()) :: Tournament.t()
  def start!(%Tournament{} = tournament, seeding \\ :standard) do
    case start(tournament, seeding) do
      {:ok, t} -> t
      {:error, reason} -> raise ArgumentError, "Failed to start tournament: #{inspect(reason)}"
    end
  end

  @spec report_score(Tournament.t(), binary(), non_neg_integer(), non_neg_integer()) ::
          {:ok, Tournament.t()} | {:error, term()}
  def report_score(%Tournament{} = tournament, match_id, p1_score, p2_score)
      when is_integer(p1_score) and is_integer(p2_score) do
    score = Score.new(p1_score, p2_score)
    Tournament.report_score(tournament, match_id, score)
  end

  @spec report_score(Tournament.t(), binary(), Score.t()) ::
          {:ok, Tournament.t()} | {:error, term()}
  def report_score(%Tournament{} = tournament, match_id, %Score{} = score) do
    Tournament.report_score(tournament, match_id, score)
  end

  @spec next_matches(Tournament.t()) :: [Bracket.Match.t()]
  def next_matches(%Tournament{} = tournament) do
    Tournament.next_matches(tournament)
  end

  @spec standings(Tournament.t()) :: [Bracket.Standings.t()]
  def standings(%Tournament{} = tournament) do
    format_module(tournament.format).standings(tournament)
  end

  @spec complete?(Tournament.t()) :: boolean()
  def complete?(%Tournament{} = tournament) do
    Tournament.complete?(tournament)
  end

  @spec reset(Tournament.t()) :: Tournament.t()
  def reset(%Tournament{} = tournament) do
    %{
      tournament
      | status: :pending,
        matches: %{},
        rounds: [],
        seeding: [],
        updated_at: DateTime.utc_now()
    }
  end

  @spec next_round(Tournament.t()) :: {:ok, Tournament.t()} | {:error, term()}
  def next_round(%Tournament{format: :swiss} = tournament) do
    Format.Swiss.generate_next_round(tournament)
  end

  def next_round(%Tournament{format: format}) do
    {:error, {:not_applicable, format}}
  end

  @spec to_ascii(Tournament.t()) :: binary()
  def to_ascii(%Tournament{} = tournament) do
    Render.ASCII.render(tournament)
  end

  @spec to_svg(Tournament.t(), keyword()) :: binary()
  def to_svg(%Tournament{} = tournament, opts \\ []) do
    Render.SVG.render(tournament, opts)
  end

  @spec to_png(Tournament.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def to_png(%Tournament{} = tournament, opts \\ []) do
    Render.PNG.render(tournament, opts)
  end

  @spec to_toml(Tournament.t()) :: binary()
  def to_toml(%Tournament{} = tournament) do
    Serialization.TOML.encode(tournament)
  end

  @spec from_toml(binary()) :: {:ok, Tournament.t()} | {:error, term()}
  def from_toml(toml) when is_binary(toml) do
    Serialization.TOML.decode(toml)
  end

  @spec from_toml!(binary()) :: Tournament.t()
  def from_toml!(toml) when is_binary(toml) do
    Serialization.TOML.decode!(toml)
  end

  defp validate_min_participants(%Tournament{participants: ps}) when length(ps) < 2 do
    {:error, :not_enough_participants}
  end

  defp validate_min_participants(_tournament), do: :ok

  defp format_module(:single_elimination), do: Format.SingleElimination
  defp format_module(:double_elimination), do: Format.DoubleElimination
  defp format_module(:round_robin), do: Format.RoundRobin
  defp format_module(:swiss), do: Format.Swiss
end
