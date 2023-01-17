defmodule TournamentRunner.SquadStrike.State do
  @enforce_keys [:tournament, :teams]
  defstruct [
    :tournament,
    :teams,
    teams_by_id: %{},
    remaining_matches: [],
    completed_matches: []
  ]

  alias Challonge.Match
  alias Challonge.Score

  def new(tournament, teams) do
    %__MODULE__{tournament: tournament, teams: teams}
  end

  def set_remaining_matches(state = %__MODULE__{}, matches) do
    remaining_matches =
      matches
      |> Enum.filter(&(&1.winner_id == nil and &1.p1_id != nil and &1.p2_id != nil))
      |> Enum.sort_by(&abs(&1.round))

    %__MODULE__{state | remaining_matches: remaining_matches}
  end

  def add_score(state = %__MODULE__{}, match = %Match{}, score = %Score{}) do
    %__MODULE__{
      state
      | remaining_matches: Enum.reject(state.remaining_matches, &(&1 == match)),
        completed_matches: [{match, score} | state.completed_matches]
    }
  end
end
