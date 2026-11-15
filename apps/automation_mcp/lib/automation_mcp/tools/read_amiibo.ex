defmodule AutomationMCP.Tools.ReadAmiibo do
  @moduledoc "Read the emulated tag's current dump back from the Picopad and write it to a file path on the daemon's host."

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Connector

  schema do
    field(:path, :string, required: true, description: "Absolute file path to write the dump to")
  end

  @impl true
  def execute(%{path: path}, frame) do
    with :ok <- validate_path(path),
         {:ok, status} <- Connector.amiibo_status(),
         {:ok, binary} <- Connector.read_amiibo(),
         :ok <- write_dump(path, binary) do
      payload = %{
        path: path,
        size: byte_size(binary),
        uid: Base.encode16(status.uid),
        state: status.state
      }

      {:reply, Response.json(Response.tool(), payload), frame}
    else
      {:error, reason} -> {:reply, Response.error(Response.tool(), format_error(reason)), frame}
    end
  end

  def validate_path(path) do
    if Path.type(path) == :absolute do
      :ok
    else
      {:error, "Path must be absolute: #{path}"}
    end
  end

  def write_dump(path, binary) do
    case File.write(path, binary) do
      :ok -> :ok
      {:error, posix} -> {:error, "Cannot write #{path}: #{:file.format_error(posix)}"}
    end
  end

  defp format_error(reason) when is_binary(reason), do: reason
  defp format_error(reason), do: inspect(reason)
end
