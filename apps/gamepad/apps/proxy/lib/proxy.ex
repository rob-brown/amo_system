defmodule Proxy do
  use GenServer

  require Logger

  alias Proxy.Queue
  alias Proxy.RespParser

  @enforce_keys [:port, :callers, :mapping]
  defstruct [:port, :callers, :mapping]

  @name __MODULE__

  def list_devices() do
    GenServer.call(@name, :list)
  end

  def connect(id) do
    GenServer.call(@name, {:connect, id})
  end

  def disconnect() do
    GenServer.cast(@name, :disconnect)
  end

  def set_mapping(mapping) do
    GenServer.cast(@name, {:set_mapping, mapping})
  end

  ## GenServer

  def start_link(_ \\ :ok) do
    GenServer.start_link(__MODULE__, [:ok], name: @name)
  end

  def init(_) do
    state = %__MODULE__{port: open_port(), callers: Queue.new(), mapping: %{}}

    {:ok, state}
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [:ok]}
    }
  end

  def handle_call(:list, from, state) do
    command = "list\n"

    if Port.command(state.port, command) do
      new_state = %__MODULE__{state | callers: Queue.push_back(state.callers, from)}
      {:noreply, new_state}
    else
      {:reply, {:error, :failed}, state}
    end
  end

  def handle_call({:connect, id}, from, state) do
    command = "connect #{id}\n"

    if Port.command(state.port, command) do
      new_state = %__MODULE__{state | callers: Queue.push_back(state.callers, from)}
      {:noreply, new_state}
    else
      {:reply, {:error, :failed}, state}
    end
  end

  def handle_cast(:disconnect, state) do
    command = "disconnect\n"
    Port.command(state.port, command)
    {:noreply, state}
  end

  def handle_cast({:command, command}, state) do
    Port.command(state.port, command)
    {:noreply, state}
  end

  def handle_info({_port, {:data, data}}, state) do
    msg = RespParser.parse(data)
    {new_queue, caller} = Queue.pop_front(state.callers)

    case {handle_response(msg, state), caller} do
      {{:reply, new_state, {:error, error}}, :empty} ->
        Logger.error("[PROXY] #{error}")
        {:noreply, new_state}

      {{:reply, new_state, msg}, :empty} ->
        Logger.error("[PROXY] Got message with no caller: #{inspect(msg)}")
        {:noreply, new_state}

      {{:reply, new_state, msg}, caller} ->
        GenServer.reply(caller, msg)
        new_state = %__MODULE__{new_state | callers: new_queue}
        {:noreply, new_state}

      {:noreply, _caller} ->
        {:noreply, state}
    end
  end

  def handle_info({_port, {:exit_status, 0}}, state) do
    _ = Logger.info("Proxy exited normally")
    {:stop, :normal, state}
  end

  def handle_info({_port, {:exit_status, code}}, state) do
    _ = Logger.error("Proxy exited: #{code}")
    {:stop, code, state}
  end

  def terminate(reason, state) do
    _ = Logger.warning("Proxy terminating because #{inspect(reason)}")
    Port.close(state.port)
  end

  ## Helpers

  defp open_port() do
    Port.open({:spawn_executable, executable()}, port_args())
  end

  defp port_args() do
    with script = priv_dir("gamepad.py"),
         args = [script] do
      [:use_stdio, :exit_status, :binary, :hide, :stderr_to_stdout, args: args]
    end
  end

  defp executable() do
    System.find_executable("python")
  end

  defp priv_dir(path) do
    Path.expand(path, :code.priv_dir(:proxy))
  end

  defp send_event([type, code, value], mapping)
       when is_integer(type) and is_integer(code) and is_integer(value) do
    Proxy.EventProcessor.process(type, code, value, mapping)
  end

  defp send_event([event], state) do
    send_event(event, state)
  end

  defp send_event(info, _state) do
    Logger.warning("[PROXY] Unknown event: #{inspect(info)}")
  end

  defp handle_response({msg, ""}, state) do
    handle_response(msg, state)
  end

  defp handle_response({:push, info}, state) do
    send_event(info, state.mapping)
    :noreply
  end

  defp handle_response(msg = ["Connected", info], state) do
    mapping = Proxy.ControllerMapping.default_mapping(info["name"])
    new_state = %__MODULE__{state | mapping: mapping}

    {:reply, new_state, msg}
  end

  defp handle_response(msg, state) do
    {:reply, state, msg}
  end
end
