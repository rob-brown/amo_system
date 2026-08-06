defmodule AutomationMCP.Tools.RunScript do
  @moduledoc """
  Run a Lua automation script through `Autopilot.LuaScript`, either a
  previously stored script (by name) or an inline script (via content).
  """

  use Anubis.Server.Component, type: :tool

  alias Anubis.Server.Response
  alias AutomationMCP.Store

  schema do
    field(:name, :string, description: "Name of a stored script to run")
    field(:content, :string, description: "Inline Lua source to run instead of a stored script")
    field(:timeout_ms, :integer, default: 5000, description: "Maximum time to let the script run")

    field(:inputs, :map,
      default: %{},
      description: "Variables to bind into the Lua script's global scope"
    )
  end

  @impl true
  def execute(params, frame) do
    with {:ok, script} <- resolve_script(params) do
      bindings = Enum.map(params.inputs, fn {k, v} -> {k, v} end)

      case run(script, bindings, params.timeout_ms) do
        :ok -> {:reply, Response.text(Response.tool(), "Script finished"), frame}
        {:error, reason} -> {:reply, Response.error(Response.tool(), inspect(reason)), frame}
      end
    else
      {:error, reason} -> {:reply, Response.error(Response.tool(), reason), frame}
    end
  end

  defp resolve_script(%{content: content}) when is_binary(content), do: {:ok, content}

  defp resolve_script(%{name: name}) when is_binary(name) do
    with {:ok, path} <- Store.lookup_script(name) do
      File.read(path)
    end
  end

  defp resolve_script(_params), do: {:error, "Provide either name or content"}

  defp run(script, bindings, timeout) do
    task =
      Task.async(Autopilot.LuaScript, :run_string, [
        script,
        [cwd: Store.image_dir(), bindings: bindings]
      ])

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, :ok} -> :ok
      {:ok, {:error, reason}} -> {:error, reason}
      nil -> {:error, "Script timed out"}
      {:exit, reason} -> {:error, {:crashed, reason}}
    end
  end
end
