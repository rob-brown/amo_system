defmodule Bracket.Standings do
  @moduledoc false

  defstruct [
    :participant_id,
    :rank,
    wins: 0,
    losses: 0,
    draws: 0,
    game_wins: 0,
    game_losses: 0,
    tiebreaker_scores: %{}
  ]

  @type t() :: %__MODULE__{
          participant_id: binary(),
          rank: pos_integer() | nil,
          wins: non_neg_integer(),
          losses: non_neg_integer(),
          draws: non_neg_integer(),
          game_wins: non_neg_integer(),
          game_losses: non_neg_integer(),
          tiebreaker_scores: %{atom() => number()}
        }

  @spec new(binary()) :: t()
  def new(participant_id) do
    %__MODULE__{participant_id: participant_id}
  end

  @spec points(t()) :: number()
  def points(%__MODULE__{wins: w, draws: d}) do
    w * 3 + d
  end

  @spec game_differential(t()) :: integer()
  def game_differential(%__MODULE__{game_wins: gw, game_losses: gl}) do
    gw - gl
  end
end
