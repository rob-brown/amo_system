defmodule TournamentRunner.CommandQueue do
  use GenServer

  require Logger

  alias TournamentRunner.MatchRunner
  alias TournamentRunner.SquadStrikeRunner
  alias TournamentRunner.Queue

  @enforce_keys [:queue, :running?]
  defstruct [:queue, :running?]

  @name __MODULE__

  def queue_match(fp1, fp2, fun) when is_function(fun, 2) do
    fp1 = read_amiibo(fp1)
    fp2 = read_amiibo(fp2)

    if fp1 != nil and fp2 != nil do
      GenServer.cast(@name, {:enqueue, {:run_match, {fp1, fp2}, fun}})
    else
      {:error, :enoexist}
    end
  end

  def queue_squad_strike([fp1, fp2, fp3], [fp4, fp5, fp6], fun) when is_function(fun, 2) do
    fp1 = read_amiibo(fp1)
    fp2 = read_amiibo(fp2)
    fp3 = read_amiibo(fp3)
    fp4 = read_amiibo(fp4)
    fp5 = read_amiibo(fp5)
    fp6 = read_amiibo(fp6)

    valid? = Enum.all?([fp1, fp2, fp3, fp4, fp5, fp6], &(&1 != nil))

    if valid? do
      GenServer.cast(@name, {:enqueue, {:run_squad, {[fp1, fp2, fp3], [fp4, fp5, fp6]}, fun}})
    else
      {:error, :enoexist}
    end
  end

  def reset_amiibo_state() do
    GenServer.cast(@name, {:enqueue, :reset_amiibo_state})
  end

  def run_function(fun) when is_function(fun, 0) do
    GenServer.cast(@name, {:enqueue, {:run_function, fun}})
  end

  def dequeue() do
    GenServer.call(@name, :dequeue)
  end

  def clear() do
    GenServer.cast(@name, :clear)
  end

  def current() do
    GenServer.call(@name, :current)
  end

  ## GenServer

  def init(_) do
    state = %__MODULE__{queue: Queue.new(), running?: false}
    {:ok, state}
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {GenServer, :start_link, [__MODULE__, [:ok], [name: @name]]}
    }
  end

  def handle_cast({:enqueue, command}, state) do
    new_queue = Queue.push_back(state.queue, command)
    new_state = %__MODULE__{state | queue: new_queue}

    if state.running? do
      {:noreply, new_state}
    else
      new_state = %__MODULE__{new_state | running?: true}
      {:noreply, new_state, {:continue, :process_command}}
    end
  end

  def handle_cast(:clear, state) do
    new_state = %__MODULE__{state | queue: Queue.new()}
    {:noreply, new_state}
  end

  def handle_cast(:process_command, state) do
    {:noreply, state, {:continue, :process_command}}
  end

  def handle_call(:dequeue, _from, state) do
    {q, command} = Queue.pop_front(state.queue)
    new_state = %__MODULE__{state | queue: q}

    {:reply, command, new_state}
  end

  def handle_call(:current, _from, state) do
    list = Enum.to_list(state.queue)

    {:reply, list, state}
  end

  def handle_continue(:process_command, state) do
    if Queue.empty?(state.queue) do
      new_state = %__MODULE__{state | running?: false}
      {:noreply, new_state}
    else
      {q, command} = Queue.pop_front(state.queue)
      new_state = %__MODULE__{state | queue: q}

      case run_command(command) do
        :run_next ->
          {:noreply, new_state, {:continue, :process_command}}

        :wait ->
          {:noreply, new_state}
      end
    end
  end

  ## Helpers

  defp run_command({:run_match, players, fun}) do
    me = self()

    Task.start(fn ->
      MatchRunner.run(players, fun)
      GenServer.cast(me, :process_command)
    end)

    :wait
  end

  defp run_command({:run_squad, players, fun}) do
    me = self()

    Task.start(fn ->
      SquadStrikeRunner.run(players, fun)
      GenServer.cast(me, :process_command)
    end)

    :wait
  end

  defp run_command(:reset_amiibo_state) do
    me = self()

    # I could watch for the task to complete or timeout if needed.
    Task.start(fn ->
      priv = :code.priv_dir(:tournament_runner)
      Autopilot.LuaScript.run_file(Path.join(priv, "clear_amiibo_cache.lua"))
      GenServer.cast(me, :process_command)
    end)

    :wait
  end

  defp run_command({:run_function, fun}) do
    fun.()
    :run_next
  end

  defp read_amiibo({:file, path}) do
    path = Path.expand(path)

    if File.exists?(path) do
      File.read!(path)
    else
      Logger.error("Invalid amiibo at #{path}")
      nil
    end
  end

  # 532 bytes may not be supported.
  defp read_amiibo({:memory, bytes}) when byte_size(bytes) in [532, 540, 572] do
    bytes
  end

  defp read_amiibo(path) when is_binary(path) do
    read_amiibo({:file, path})
  end

  defp read_amiibo(input) do
    Logger.error("Invalid amiibo #{inspect(input)}")
    nil
  end
end
