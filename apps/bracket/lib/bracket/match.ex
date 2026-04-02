defmodule Bracket.Match do
  @moduledoc false

  alias Bracket.Score

  defstruct [
    :id,
    :round,
    :position,
    :p1_id,
    :p2_id,
    :p1_prereq_match,
    :p2_prereq_match,
    :winner_id,
    :loser_id,
    :score,
    :winner_feeds,
    :loser_feeds,
    status: :pending,
    metadata: %{}
  ]

  @type slot() :: :p1 | :p2
  @type feed() :: {binary(), slot()} | nil

  @type t() :: %__MODULE__{
          id: binary(),
          round: integer(),
          position: non_neg_integer(),
          p1_id: binary() | nil,
          p2_id: binary() | nil,
          p1_prereq_match: binary() | nil,
          p2_prereq_match: binary() | nil,
          winner_id: binary() | nil,
          loser_id: binary() | nil,
          score: Score.t() | nil,
          winner_feeds: feed(),
          loser_feeds: feed(),
          status: :pending | :ready | :in_progress | :complete | :bye,
          metadata: map()
        }

  @spec new(keyword()) :: t()
  def new(fields) do
    struct(__MODULE__, fields)
  end

  @spec ready?(t()) :: boolean()
  def ready?(%__MODULE__{p1_id: p1, p2_id: p2}) do
    p1 != nil and p2 != nil
  end
end
