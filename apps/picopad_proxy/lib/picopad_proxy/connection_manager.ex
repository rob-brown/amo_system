defmodule PicopadProxy.ConnectionManager do
  use GenServer

  require Logger

  @connection_topic "picopad:connection"
  @event_topic "picopad:events"

  defmodule State do
    @enforce_keys [:picopad_pid, :port, :status]
    defstruct [:picopad_pid, :port, :status, :last_error, :player_number]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def connect(port) when is_binary(port) do
    GenServer.call(__MODULE__, {:connect, port})
  end

  def disconnect do
    GenServer.call(__MODULE__, :disconnect)
  end

  def start_advertising do
    GenServer.call(__MODULE__, :start_advertising)
  end

  def stop_advertising do
    GenServer.call(__MODULE__, :stop_advertising)
  end

  def forget_bonding do
    GenServer.call(__MODULE__, :forget_bonding)
  end

  def reconnect do
    GenServer.call(__MODULE__, :reconnect)
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
    state = %State{
      picopad_pid: nil,
      port: nil,
      status: :disconnected
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:connect, port}, _from, state) do
    case Picopad.connect(port) do
      {:ok, pid} ->
        setup_event_handlers(pid)

        new_state =
          case Picopad.status(pid) do
            {:ok, info} ->
              status =
                case info.connection do
                  :disconnected -> :connected
                  :advertising -> :advertising
                  :pairing -> :pairing
                  :ready -> :paired
                  _ -> :connected
                end

              %State{
                state
                | picopad_pid: pid,
                  port: port,
                  status: status,
                  player_number: info.player,
                  last_error: nil
              }

            {:error, _reason} ->
              %State{
                state
                | picopad_pid: pid,
                  port: port,
                  status: :connected,
                  last_error: nil
              }
          end

        broadcast_connection_changed(new_state)
        {:reply, :ok, new_state}

      {:error, reason} = error ->
        new_state = %State{state | last_error: inspect(reason)}
        broadcast_error(reason)
        {:reply, error, new_state}
    end
  end

  @impl true
  def handle_call(:disconnect, _from, state) do
    if state.picopad_pid do
      Picopad.disconnect(state.picopad_pid)
    end

    new_state = %State{
      state
      | picopad_pid: nil,
        status: :disconnected
    }

    broadcast_connection_changed(new_state)
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:start_advertising, _from, state) do
    if state.picopad_pid do
      result = Picopad.start_advertising(state.picopad_pid)

      case result do
        :ok ->
          new_state = %State{state | status: :advertising}
          broadcast_connection_changed(new_state)
          {:reply, :ok, new_state}

        error ->
          {:reply, error, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:stop_advertising, _from, state) do
    if state.picopad_pid do
      result = Picopad.stop_advertising(state.picopad_pid)

      case result do
        :ok ->
          new_state = %State{state | status: :connected}
          broadcast_connection_changed(new_state)
          {:reply, :ok, new_state}

        error ->
          {:reply, error, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:forget_bonding, _from, state) do
    if state.picopad_pid do
      result = Picopad.forget_bonding(state.picopad_pid)
      {:reply, result, state}
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:reconnect, _from, state) do
    if state.picopad_pid do
      result = Picopad.reconnect(state.picopad_pid)
      {:reply, result, state}
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call({:load_amiibo, data}, _from, state) do
    if state.picopad_pid do
      result = Picopad.load_amiibo(state.picopad_pid, data)

      case result do
        {:ok, info} ->
          broadcast_event({:amiibo_loaded, info})
          {:reply, :ok, state}

        error ->
          {:reply, error, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:clear_amiibo, _from, state) do
    if state.picopad_pid do
      result = Picopad.clear_amiibo(state.picopad_pid)

      case result do
        :ok ->
          broadcast_event(:amiibo_cleared)
          {:reply, :ok, state}

        error ->
          {:reply, error, state}
      end
    else
      {:reply, {:error, :not_connected}, state}
    end
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:status, :port, :player_number, :last_error]), state}
  end

  @impl true
  def handle_call(:picopad_pid, _from, state) do
    {:reply, state.picopad_pid, state}
  end

  @impl true
  def handle_info({:picopad_event, :connection_changed, payload}, state) do
    info = Picopad.Protocol.parse_status_payload(payload)

    status =
      case info.connection do
        :disconnected -> :connected
        :advertising -> :advertising
        :pairing -> :pairing
        :ready -> :paired
        _ -> :connected
      end

    new_state = %State{state | status: status, player_number: info.player}
    broadcast_connection_changed(new_state)
    {:noreply, new_state}
  end

  @impl true
  def handle_info({:picopad_event, :amiibo_scanned, payload}, state) do
    broadcast_event({:amiibo_scanned, payload})
    {:noreply, state}
  end

  @impl true
  def handle_info({:picopad_event, :log, payload}, state) do
    log_info = Picopad.Protocol.parse_log_payload(payload)

    Logger.log(
      log_info.level,
      "[Picopad] #{log_info.message}"
    )

    {:noreply, state}
  end

  @impl true
  def handle_info({:picopad_event, _event, _payload}, state) do
    {:noreply, state}
  end

  defp setup_event_handlers(pid) do
    handler = fn %{event: event, payload: payload} ->
      send(__MODULE__, {:picopad_event, event, payload})
    end

    Picopad.on_event(pid, :connection_changed, handler)
    Picopad.on_event(pid, :amiibo_scanned, handler)
    Picopad.on_event(pid, :log, handler)
  end

  defp broadcast_connection_changed(state) do
    Phoenix.PubSub.broadcast(
      PicopadProxy.PubSub,
      @connection_topic,
      {:connection_changed, Map.take(state, [:status, :port, :player_number])}
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
      {:error, inspect(reason)}
    )
  end
end
