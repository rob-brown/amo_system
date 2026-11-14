defmodule PicopadProxy.ConnectionManager do
  use GenServer

  require Logger

  alias PicopadProxy.ConnectionStatus
  alias PicopadProxy.Errors
  alias PicopadProxy.PortFinder

  @connection_topic "picopad:connection"
  @event_topic "picopad:events"
  @radio_commands [:start_advertising, :stop_advertising, :forget_bonding, :reconnect]
  @info_keys [:status, :port, :player_number, :last_error, :firmware, :controller]
  @retry_delay 5_000
  @lost_delay 2_000
  @settle_delay 100
  @discovery_timeout 20_000

  defmodule State do
    @enforce_keys [:picopad_pid, :port, :status]
    defstruct [
      :picopad_pid,
      :port,
      :status,
      :last_error,
      :player_number,
      :firmware,
      :controller
    ]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def connect(port) when is_binary(port) do
    GenServer.call(__MODULE__, {:connect, port}, @discovery_timeout)
  end

  def auto_connect do
    GenServer.call(__MODULE__, :auto_connect, @discovery_timeout)
  end

  def disconnect do
    GenServer.call(__MODULE__, :disconnect)
  end

  def start_advertising do
    GenServer.call(__MODULE__, {:radio, :start_advertising})
  end

  def stop_advertising do
    GenServer.call(__MODULE__, {:radio, :stop_advertising})
  end

  def forget_bonding do
    GenServer.call(__MODULE__, {:radio, :forget_bonding})
  end

  def reconnect do
    GenServer.call(__MODULE__, {:radio, :reconnect})
  end

  def load_amiibo(data) when is_binary(data) do
    GenServer.call(__MODULE__, {:load_amiibo, data}, 10_000)
  end

  def clear_amiibo do
    GenServer.call(__MODULE__, :clear_amiibo)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def picopad_pid do
    GenServer.call(__MODULE__, :picopad_pid)
  end

  @impl true
  def init(_opts) do
    Process.flag(:trap_exit, true)

    state = %State{picopad_pid: nil, port: nil, status: :disconnected}

    if Application.get_env(:picopad_proxy, :auto_connect, true) do
      send(self(), :auto_connect)
    end

    {:ok, state}
  end

  @impl true
  def handle_call({:connect, port}, _from, state) do
    dropped = drop_connection(state)

    case establish(dropped, port) do
      {:ok, new_state} ->
        broadcast_connection_changed(new_state)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, fail(dropped, reason)}
    end
  end

  def handle_call(:auto_connect, _from, %State{picopad_pid: pid} = state) when is_pid(pid) do
    {:reply, :ok, state}
  end

  def handle_call(:auto_connect, _from, state) do
    case discover(state) do
      {:ok, new_state} ->
        broadcast_connection_changed(new_state)
        {:reply, :ok, new_state}

      {:error, reason} ->
        {:reply, {:error, reason}, fail(state, reason)}
    end
  end

  def handle_call(:disconnect, _from, state) do
    new_state = drop_connection(state)
    broadcast_connection_changed(new_state)
    {:reply, :ok, new_state}
  end

  def handle_call({:radio, _command}, _from, %State{picopad_pid: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:radio, command}, _from, state) when command in @radio_commands do
    case call_device(fn -> apply(Picopad, command, [state.picopad_pid]) end) do
      :ok ->
        new_state = refresh_status(state)
        broadcast_connection_changed(new_state)
        {:reply, :ok, new_state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call({:load_amiibo, _data}, _from, %State{picopad_pid: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call({:load_amiibo, data}, _from, state) do
    case call_device(fn -> Picopad.load_amiibo(state.picopad_pid, data) end) do
      {:ok, info} ->
        broadcast_event({:amiibo_loaded, info})
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:clear_amiibo, _from, %State{picopad_pid: nil} = state) do
    {:reply, {:error, :not_connected}, state}
  end

  def handle_call(:clear_amiibo, _from, state) do
    case call_device(fn -> Picopad.clear_amiibo(state.picopad_pid) end) do
      :ok ->
        broadcast_event(:amiibo_cleared)
        {:reply, :ok, state}

      error ->
        {:reply, error, state}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, @info_keys), state}
  end

  def handle_call(:picopad_pid, _from, state) do
    {:reply, state.picopad_pid, state}
  end

  @impl true
  def handle_info({:picopad_event, :connection_changed, payload}, %State{} = state) do
    case Picopad.Protocol.parse_connection_changed_payload(payload) do
      :error ->
        {:noreply, state}

      info ->
        new_state = %State{state | status: ConnectionStatus.from_firmware(info.connection)}
        broadcast_connection_changed(new_state)
        {:noreply, new_state}
    end
  end

  def handle_info({:picopad_event, :amiibo_scanned, payload}, state) do
    broadcast_event({:amiibo_scanned, payload})
    {:noreply, state}
  end

  def handle_info({:picopad_event, event, _payload}, state)
      when event in [:bonding_cleared, :reconnect_success, :reconnect_failed] do
    broadcast_event(event)
    {:noreply, state}
  end

  def handle_info({:picopad_event, :log, payload}, state) do
    log_info = Picopad.Protocol.parse_log_payload(payload)
    Logger.log(log_info.level, "[Picopad] #{log_info.message}")
    {:noreply, state}
  end

  def handle_info({:picopad_event, _event, _payload}, state) do
    {:noreply, state}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, %State{picopad_pid: pid} = state) do
    handle_picopad_down(state)
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    {:noreply, state}
  end

  def handle_info({:EXIT, pid, _reason}, %State{picopad_pid: pid} = state) do
    handle_picopad_down(state)
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    {:noreply, state}
  end

  def handle_info(:auto_connect, %State{picopad_pid: nil} = state) do
    case discover(state) do
      {:ok, new_state} ->
        broadcast_connection_changed(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        {:noreply, note_failure(state, reason)}
    end
  end

  def handle_info(:auto_connect, state) do
    {:noreply, state}
  end

  def handle_info(:attempt_reconnect, %State{picopad_pid: nil} = state) do
    case discover(state, settle: @settle_delay) do
      {:ok, new_state} ->
        broadcast_connection_changed(new_state)
        {:noreply, new_state}

      {:error, reason} ->
        Process.send_after(self(), :attempt_reconnect, @retry_delay)
        {:noreply, note_failure(state, reason)}
    end
  end

  def handle_info(:attempt_reconnect, state) do
    {:noreply, state}
  end

  defp handle_picopad_down(%State{} = state) do
    Logger.notice("Picopad connection lost, attempting to reconnect...")

    new_state = %State{
      state
      | picopad_pid: nil,
        port: nil,
        status: :disconnected,
        player_number: nil,
        firmware: nil,
        controller: nil
    }

    broadcast_connection_changed(new_state)
    Process.send_after(self(), :attempt_reconnect, @lost_delay)

    {:noreply, new_state}
  end

  defp discover(state, opts \\ []) do
    with {:ok, port} <- PortFinder.find(finder_opts()) do
      establish(state, port, opts)
    end
  end

  defp establish(state, port, opts \\ []) do
    case Errors.normalize(Picopad.connect(port, connect_opts())) do
      {:ok, pid} ->
        Process.monitor(pid)
        register_event_handler(pid)
        Process.sleep(Keyword.get(opts, :settle, 0))
        read_device(state, pid, port)

      {:error, _reason} = error ->
        error
    end
  end

  defp read_device(%State{} = state, pid, port) do
    connected = %State{
      state
      | picopad_pid: pid,
        port: port,
        status: :connected,
        last_error: nil
    }

    case call_device(fn -> {:ok, connected |> refresh_status() |> detect_firmware()} end) do
      {:ok, _new_state} = ok ->
        ok

      {:error, _reason} = error ->
        close_quietly(pid)
        error
    end
  end

  defp refresh_status(%State{} = state) do
    case Picopad.status(state.picopad_pid) do
      {:ok, %{connection: connection, player: player, controller: controller}} ->
        %State{
          state
          | status: ConnectionStatus.from_firmware(connection),
            player_number: player,
            controller: controller
        }

      _other ->
        state
    end
  end

  defp detect_firmware(%State{} = state) do
    case Picopad.firmware(state.picopad_pid) do
      {:ok, firmware} -> %State{state | firmware: firmware}
      _other -> state
    end
  end

  defp call_device(fun) do
    Errors.normalize(fun.())
  catch
    :exit, {:timeout, _call} -> {:error, :no_response}
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp drop_connection(%State{picopad_pid: nil} = state), do: state

  defp drop_connection(%State{} = state) do
    close_quietly(state.picopad_pid)

    %State{
      state
      | picopad_pid: nil,
        status: :disconnected,
        player_number: nil,
        firmware: nil,
        controller: nil
    }
  end

  defp close_quietly(pid) do
    Picopad.disconnect(pid)
  catch
    :exit, _reason -> :ok
  end

  defp note_failure(state, :not_found), do: state

  defp note_failure(%State{} = state, reason) do
    %State{state | last_error: Errors.message(reason)}
  end

  defp fail(%State{} = state, reason) do
    new_state = %State{state | last_error: Errors.message(reason)}
    broadcast_error(reason)
    broadcast_connection_changed(new_state)
    new_state
  end

  defp finder_opts do
    configured = Application.get_env(:picopad_proxy, :port_finder, [])
    probe_opts = Keyword.merge(connect_opts(), Keyword.get(configured, :probe_opts, []))
    Keyword.put(configured, :probe_opts, probe_opts)
  end

  defp connect_opts do
    Application.get_env(:picopad_proxy, :picopad_connect_opts, [])
  end

  defp register_event_handler(pid) do
    handler = fn %{event: event, payload: payload} ->
      send(__MODULE__, {:picopad_event, event, payload})
    end

    Picopad.on_event(pid, :all, handler)
  end

  defp broadcast_connection_changed(state) do
    Phoenix.PubSub.broadcast(
      PicopadProxy.PubSub,
      @connection_topic,
      {:connection_changed, Map.take(state, @info_keys)}
    )
  end

  defp broadcast_event(event) do
    Phoenix.PubSub.broadcast(
      PicopadProxy.PubSub,
      @event_topic,
      {:picopad_event, event}
    )
  end

  defp broadcast_error(reason) do
    Phoenix.PubSub.broadcast(
      PicopadProxy.PubSub,
      @connection_topic,
      {:error, Errors.message(reason)}
    )
  end
end
