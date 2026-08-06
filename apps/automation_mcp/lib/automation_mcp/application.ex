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
      {AutomationMCP.CaptureDevice, capture_device_names()},
      AutomationMCP.Connector,
      {AutomationMCP.Server, transport: :stdio}
    ]
  end

  defp capture_device_names do
    Application.get_env(:automation_mcp, :capture_device_names, ["ShadowCast"])
  end
end
