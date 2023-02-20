defmodule AmiiboManager.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AmiiboManager.Repo
    ]

    opts = [strategy: :one_for_one, name: AmiiboManager.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
