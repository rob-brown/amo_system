defmodule AutomationMCP.HTTPRouter do
  @moduledoc """
  Minimal Plug pipeline exposing `AutomationMCP.Server` over MCP's
  streamable HTTP transport, so multiple agent sessions can share one
  running server instead of each spawning its own process (and each
  fighting over the Picopad/capture card).
  """

  use Plug.Router

  plug(:match)
  plug(:dispatch)

  forward("/mcp",
    to: Anubis.Server.Transport.StreamableHTTP.Plug,
    server: AutomationMCP.Server,
    subscriber_metadata: &__MODULE__.no_metadata/1
  )

  match _ do
    send_resp(conn, 404, "Not found")
  end

  @doc false
  def no_metadata(_conn), do: %{}
end
