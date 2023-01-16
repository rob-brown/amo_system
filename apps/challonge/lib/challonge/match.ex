defmodule Challonge.Match do
  require Logger

  alias Challonge.Score

  defstruct [:id, :p1_id, :p2_id, :round, :scores, :winner_id]

  @type t() :: %__MODULE__{
          id: integer(),
          p1_id: integer(),
          p2_id: integer(),
          round: integer(),
          scores: [Score.t()],
          winner_id: integer()
        }

  def parse(json) do
    case json do
      %{
        "match" => %{
          "id" => id,
          "player1_id" => p1_id,
          "player2_id" => p2_id,
          "round" => round,
          "scores_csv" => scores_csv,
          "winner_id" => winner_id
        }
      } ->
        match = %__MODULE__{
          id: id,
          p1_id: p1_id,
          p2_id: p2_id,
          round: round,
          scores: Score.parse_csv(scores_csv),
          winner_id: winner_id
        }

        {:ok, match}

      other ->
        Logger.error("Bad match #{inspect(other)}")
        {:error, :bad_data}
    end
  end
end
