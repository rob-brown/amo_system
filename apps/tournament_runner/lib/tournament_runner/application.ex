defmodule TournamentRunner.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Joycontrol,
      Vision
    ]

    opts = [strategy: :one_for_one, name: TournamentRunner.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
