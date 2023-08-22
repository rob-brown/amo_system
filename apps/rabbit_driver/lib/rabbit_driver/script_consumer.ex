defmodule RabbitDriver.ScriptConsumer do
  @behaviour RabbitDriver.Consumer

  @lua_type "application/x-lua"

  alias RabbitDriver.ImageConsumer
  alias RabbitDriver.DataURL

  def start_link(opts) do
    defaults = [module: __MODULE__, topics: ["script.#"], queue: "script_consumer"]
    opts = Keyword.merge(defaults, opts)
    RabbitDriver.Consumer.start_link(opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def script_dir() do
    Path.join(System.tmp_dir(), "rabbit-driver-scripts")
  end

  @impl RabbitDriver.Consumer
  def init(_opts) do
    _ = File.mkdir_p(script_dir())
  end

  @impl RabbitDriver.Consumer
  def handle_msg(~w"script list", _payload) do
    {:reply, %{scripts: scripts()}}
  end

  def handle_msg(~w"script get", payload) do
    scripts = scripts()
    name = Map.get(payload, "name")

    if name in scripts do
      bytes = name |> path() |> File.read!()

      response = %{
        script: %{
          name: name,
          size: byte_size(bytes),
          encoding: :plain,
          bytes: bytes
        }
      }

      {:reply, response}
    else
      {:reply, %{script: nil, error: "Not found"}}
    end
  end

  def handle_msg(~w"script put", %{"name" => name, "bytes" => bytes}) do
    {:ok, bytes} = parse_raw(bytes)
    File.write!(path(name), bytes)
    :noreply
  end

  def handle_msg(~w"script delete", %{"name" => name}) do
    path = path(name)

    if File.regular?(path) do
      File.rm!(path)
    end

    :noreply
  end

  def handle_msg(~w"script run", payload = %{"name" => name}) do
    timeout = Map.get(payload, "timeout_ms", :timer.seconds(5))
    args = payload |> Map.get("inputs", []) |> process_args()
    path = path(name)

    if File.exists?(path) and File.regular?(path) do
      script = File.read!(path)

      case run_script(script, args, timeout) do
        :ok ->
          {:reply, %{error: nil}}

        {:error, reason} ->
          {:reply, %{error: reason}}
      end
    else
      {:reply, %{error: "Script doesn't exist"}}
    end
  end

  def handle_msg(~w"script run", payload = %{"raw" => raw}) do
    with {:ok, script} <- parse_raw(raw),
         timeout = Map.get(payload, "timeout_ms", :timer.seconds(5)),
         args = payload |> Map.get("inputs", []) |> process_args(),
         :ok <- run_script(script, args, timeout) do
      {:reply, %{error: nil}}
    else
      {:error, reason} ->
        {:reply, %{error: reason}}
    end
  end

  def handle_msg(topic, _payload) do
    {:error, "Unknown message #{topic}"}
  end

  ## Helpers

  defp path(name) do
    if String.ends_with?(name, ".lua") do
      Path.join(script_dir(), name)
    else
      Path.join(script_dir(), name <> ".lua")
    end
  end

  defp scripts() do
    File.ls!(script_dir())
  end

  defp parse_raw(raw) do
    case DataURL.decode(raw) do
      {:ok, @lua_type, _param, decoded} ->
        {:ok, decoded}

      {:ok, type, _param, _decoded} ->
        {:error, "Expected file type '#{@lua_type}' got '#{type}'"}

      _ ->
        {:ok, raw}
    end
  end

  defp run_script(script, args, timeout) do
    task =
      Task.async(Autopilot.LuaScript, :run_string, [
        script,
        [{:cwd, ImageConsumer.image_dir()}, {:bindings, args}]
      ])

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, :ok} ->
        :ok

      {:ok, {:error, reason}} ->
        {:error, "Script error #{inspect(reason)}"}

      nil ->
        {:error, "Script timed out"}

      {:exit, reason} ->
        {:error, "Task crashed #{inspect(reason)}"}
    end
  end

  defp process_args(list_or_map) do
    Enum.map(list_or_map, &process_arg/1)
  end

  defp process_arg({key, data = "data:" <> _}) do
    {:ok, _type, _param, value} = DataURL.decode(data)

    {key, value}
  end

  defp process_arg({key, value}) when is_list(value) do
    {key, process_args(value)}
  end

  defp process_arg({key, value}) when not is_map(value) do
    {key, value}
  end
end
