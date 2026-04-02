defmodule Bracket.Format do
  @moduledoc false

  alias Bracket.{Standings, Tournament}

  @callback generate_matches(Tournament.t()) :: {:ok, Tournament.t()} | {:error, term()}
  @callback standings(Tournament.t()) :: [Standings.t()]
  @callback complete?(Tournament.t()) :: boolean()
end
