defmodule SquadStrike.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      SquadStrike.MQ
    ]

    opts = [strategy: :one_for_one, name: SquadStrike.Supervisor]
    Supervisor.start_link(children(), opts)
  end
end
