defmodule RabbitDriver.ScriptConsumer do
  @behaviour RabbitDriver.Consumer

  def start_link(opts) do
    defaults = [module: __MODULE__, topics: ["script.run"], queue: "script_consumer"]
    opts = Keyword.merge(defaults, opts)
    RabbitDriver.Consumer.start_link(opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @impl RabbitDriver.Consumer
  def init(_opts) do
    _ = File.mkdir_p(script_dir())
  end

  @impl RabbitDriver.Consumer
  def handle_msg(~w"script run", payload = %{"name" => name}) do
    timeout = Map.get(payload, "timeout_ms", :timer.seconds(5))
    path = path(name)

    if File.exists?(path) and File.regular?(path) do
      task = Task.async(Autopilot.LuaScript, :run_file, [path])

      case Task.yield(task, timeout) || Task.shutdown(task) do
        {:ok, :ok} ->
          {:reply, %{error: nil}}

        {:ok, {:error, reason}} ->
          {:reply, %{error: "Script error #{inspect(reason)}"}}

        nil ->
          {:reply, %{error: "Script timed out"}}

        {:exit, reason} ->
          {:reply, %{error: "Task crashed #{inspect(reason)}"}}
      end
    else
      {:reply, %{error: "Script doesn't exist"}}
    end
  end

  def handle_msg(~w"script run", payload = %{"raw" => string}) do
    timeout = Map.get(payload, "timeout_ms", :timer.seconds(5))

    task = Task.async(Autopilot.LuaScript, :run_string, [string])

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, :ok} ->
        {:reply, %{error: nil}}

      {:ok, {:error, reason}} ->
        {:reply, %{error: "Script error #{inspect(reason)}"}}

      nil ->
        {:reply, %{error: "Script timed out"}}

      {:exit, reason} ->
        {:reply, %{error: "Task crashed #{inspect(reason)}"}}
    end
  end

  def handle_msg(topic, _payload) do
    {:error, "Unknown message #{topic}"}
  end

  ## Helpers

  defp script_dir() do
    Path.join(System.tmp_dir(), "rabbit-driver-scripts")
  end

  defp path(name) do
    Path.join(script_dir(), name)
  end
end
