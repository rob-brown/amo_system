defmodule SquadStrike.Script do
  alias SquadStrike.DataURL

  def eval(path, opts \\ []) do
    timeout = Keyword.get(opts, :timeout) || :timer.seconds(5)
    args = opts |> Keyword.get(:args, []) |> process_args()
    cwd = Keyword.get(opts, :cwd) || image_dir()

    path
    |> script()
    |> File.read()
    |> case do
      {:ok, script} ->
        run_script(script, args, cwd, timeout)

      {:error, reason} ->
        {:error, reason}
    end
  end

  ## Helpers

  defp image_dir() do
    Path.join(:code.priv_dir(:squad_strike), "images")
  end

  defp run_script(script, args, cwd, timeout) do
    task =
      Task.async(Autopilot.LuaScript, :run_string, [
        script,
        [{:cwd, cwd}, {:bindings, args}]
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

  defp script(name) do
    Path.expand("scripts/#{name}.lua", :code.priv_dir(:squad_strike))
  end
end
