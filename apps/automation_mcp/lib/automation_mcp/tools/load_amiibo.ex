defmodule AutomationMCP.Tools.LoadAmiibo do
  @moduledoc "Load a base64-encoded amiibo dump (532, 540, or 572 bytes) into the Picopad's emulated tag."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector

  schema do
    field(:data, :string, required: true, description: "Base64-encoded amiibo binary")
  end

  @impl true
  def execute(%{data: data}, frame) do
    with {:ok, binary} <- Base.decode64(data),
         :ok <- validate_binary_size(binary),
         {:ok, info} <- Connector.load_amiibo(binary) do
      {:reply, Response.json(Response.tool(), %{uid: Base.encode16(info.uid)}), frame}
    else
      :error -> {:reply, Response.error(Response.tool(), "Invalid base64 data"), frame}
      {:error, reason} -> {:reply, Response.error(Response.tool(), inspect(reason)), frame}
    end
  end

  defp validate_binary_size(binary) when byte_size(binary) in [532, 540, 572] do
    :ok
  end

  defp validate_binary_size(_) do
    {:error, "Amiibo data must be 532, 540, or 572 bytes"}
  end
end
