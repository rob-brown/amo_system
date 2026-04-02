defmodule Bracket.Config do
  @moduledoc false

  defstruct best_of: 1,
            third_place_match: false,
            grand_finals_modifier: :standard,
            swiss_rounds: nil,
            swiss_system: :monrad,
            tiebreakers: [:buchholz, :wins],
            allow_draws: false

  @type format() :: :single_elimination | :double_elimination | :round_robin | :swiss
  @type grand_finals_modifier() :: :standard | :reset
  @type swiss_system() :: :monrad | :dutch
  @type tiebreaker() :: :buchholz | :median_buchholz | :sonneborn_berger | :progressive | :wins

  @type t() :: %__MODULE__{
          best_of: pos_integer(),
          third_place_match: boolean(),
          grand_finals_modifier: grand_finals_modifier(),
          swiss_rounds: pos_integer() | nil,
          swiss_system: swiss_system(),
          tiebreakers: [tiebreaker()],
          allow_draws: boolean()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end
end
