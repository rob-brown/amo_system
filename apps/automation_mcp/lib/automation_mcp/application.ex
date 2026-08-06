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
      AutomationMCP.Connector
    ] ++ server_children(transport())
  end

  # Default: one process per client, spawned by whatever launched it (e.g. a
  # stdio-based Claude Desktop/Code config). Simple, but two clients means
  # two processes fighting over the same Picopad/capture card.
  defp server_children(:stdio) do
    [{AutomationMCP.Server, transport: :stdio}]
  end

  # Run once as a long-lived daemon; every client connects to this same
  # process over HTTP, so the hardware only ever has one owner regardless of
  # how many agent sessions are attached.
  defp server_children({:http, port, ip}) do
    [
      {AutomationMCP.Server, transport: {:streamable_http, [start: true]}},
      {Bandit, plug: AutomationMCP.HTTPRouter, port: port, ip: ip}
    ]
  end

  defp transport do
    case System.get_env("AUTOMATION_MCP_TRANSPORT", "stdio") do
      "http" ->
        port = System.get_env("AUTOMATION_MCP_HTTP_PORT", "4000") |> String.to_integer()
        {:http, port, http_bind_ip()}

      _ ->
        :stdio
    end
  end

  # Loopback-only by default: this controls a real Switch, so nothing else
  # on the network should be able to reach it without an explicit opt-in.
  defp http_bind_ip do
    case System.get_env("AUTOMATION_MCP_HTTP_BIND") do
      "any" -> {0, 0, 0, 0}
      _ -> {127, 0, 0, 1}
    end
  end

  defp capture_device_names do
    Application.get_env(:automation_mcp, :capture_device_names, ["ShadowCast"])
  end
end
