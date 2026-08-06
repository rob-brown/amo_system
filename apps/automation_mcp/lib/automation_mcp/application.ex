defmodule AutomationMCP.Application do
  @moduledoc false

  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    AutomationMCP.Store.ensure_dirs!()

    opts = [strategy: :one_for_one, name: AutomationMCP.Supervisor]
    Supervisor.start_link(children(@env), opts)
  end

  defp children(:test) do
    []
  end

  defp children(_env) do
    [
      AutomationMCP.Connector,
      {AutomationMCP.Server, transport: :stdio}
    ]
  end
end
