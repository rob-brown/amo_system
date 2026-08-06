defmodule AutomationMCP.Connector do
  @moduledoc """
  Owns the Picopad USB connection. On startup, scans serial ports and connects
  to the first one that responds to the Picopad protocol, mirroring the
  connect/status/event-handling logic in `PicopadProxy.ConnectionManager`.
  """

  use GenServer

  require Logger

  defmodule State do
    @enforce_keys [:status]
    defstruct [:picopad_pid, :port, :status, :last_error, :player_number]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def status do
    GenServer.call(__MODULE__, :status)
  end

  def picopad_pid do
    GenServer.call(__MODULE__, :picopad_pid)
  end

  def rescan do
    GenServer.call(__MODULE__, :rescan, :timer.seconds(15))
  end

  def connect(port) when is_binary(port) do
    GenServer.call(__MODULE__, {:connect, port})
  end

  def load_amiibo(data) when is_binary(data) do
    GenServer.call(__MODULE__, {:load_amiibo, data}, :timer.seconds(10))
  end

  def clear_amiibo do
    GenServer.call(__MODULE__, :clear_amiibo)
  end

  def amiibo_status do
    GenServer.call(__MODULE__, :amiibo_status)
  end

  def press(button, duration) when is_atom(button) and is_integer(duration) do
    GenServer.call(__MODULE__, {:press, button, duration}, duration + :timer.seconds(5))
  end

  def hold(buttons) when is_list(buttons) do
    GenServer.call(__MODULE__, {:hold, buttons})
  end

  def release(buttons) when is_list(buttons) do
    GenServer.call(__MODULE__, {:release, buttons})
  end

  def release_all do
    GenServer.call(__MODULE__, :release_all)
  end

  def stick(which, value) do
    GenServer.call(__MODULE__, {:stick, which, value})
  end

  @impl true
  def init(_opts) do
    {:ok, %State{status: :disconnected}, {:continue, :auto_connect}}
  end

  @impl true
  def handle_continue(:auto_connect, state) do
    {:noreply, discover_and_connect(state)}
  end

  @impl true
  def handle_call(:status, _from, state) do
    {:reply, Map.take(state, [:status, :port, :player_number, :last_error]), state}
  end

  def handle_call(:picopad_pid, _from, state) do
    {:reply, state.picopad_pid, state}
  end

  def handle_call(:rescan, _from, state) do
    new_state = discover_and_connect(disconnect_state(state))
    {:reply, Map.take(new_state, [:status, :port, :player_number, :last_error]), new_state}
  end

  def handle_call({:connect, port}, _from, %State{} = state) do
    case attempt_connect(port) do
      {:ok, new_state} ->
        {:reply, :ok, new_state}

      :error ->
        new_state = %State{state | last_error: "No response from #{port}"}
        {:reply, {:error, :not_connected}, new_state}
    end
  end

  def handle_call({:load_amiibo, data}, _from, state) do
    with_pid(state, fn pid -> Picopad.load_amiibo(pid, data) end)
  end

  def handle_call(:clear_amiibo, _from, state) do
    with_pid(state, fn pid -> Picopad.clear_amiibo(pid) end)
  end

  def handle_call(:amiibo_status, _from, state) do
    with_pid(state, fn pid -> Picopad.amiibo_status(pid) end)
  end

  def handle_call({:press, button, duration}, _from, state) do
    with_pid(state, fn pid -> Picopad.press(pid, button, duration) end)
  end

  def handle_call({:hold, buttons}, _from, state) do
    with_pid(state, fn pid -> Picopad.hold(pid, buttons) end)
  end

  def handle_call({:release, buttons}, _from, state) do
    with_pid(state, fn pid -> Picopad.release(pid, buttons) end)
  end

  def handle_call(:release_all, _from, state) do
    with_pid(state, fn pid -> Picopad.release_all(pid) end)
  end

  def handle_call({:stick, which, value}, _from, state) do
    with_pid(state, fn pid -> Picopad.stick(pid, which, value) end)
  end

  @impl true
  def handle_info({:picopad_event, :connection_changed, payload}, %State{} = state) do
    info = Picopad.Protocol.parse_status_payload(payload)

    new_state = %State{
      state
      | status: connection_status(info.connection),
        player_number: info.player
    }

    {:noreply, new_state}
  end

  def handle_info({:picopad_event, :log, payload}, state) do
    log_info = Picopad.Protocol.parse_log_payload(payload)
    Logger.log(log_info.level, "[Picopad] #{log_info.message}")
    {:noreply, state}
  end

  def handle_info({:picopad_event, _event, _payload}, state) do
    {:noreply, state}
  end

  ## Helpers

  defp with_pid(state = %State{picopad_pid: nil}, _fun) do
    {:reply, {:error, :not_connected}, state}
  end

  defp with_pid(state = %State{picopad_pid: pid}, fun) do
    {:reply, fun.(pid), state}
  end

  defp disconnect_state(state) do
    if state.picopad_pid, do: Picopad.disconnect(state.picopad_pid)
    %State{status: :disconnected}
  end

  defp discover_and_connect(state) do
    case candidate_ports() do
      [] ->
        Logger.warning("No serial ports available for Picopad auto-connect")
        state

      ports ->
        try_ports(ports, state)
    end
  end

  defp try_ports([], state) do
    Logger.warning("Could not find a responding Picopad on any serial port")
    state
  end

  defp try_ports([port | rest], state) do
    case attempt_connect(port) do
      {:ok, new_state} -> new_state
      :error -> try_ports(rest, state)
    end
  end

  defp attempt_connect(port) do
    case Picopad.connect(port) do
      {:ok, pid} ->
        case safe_status(pid) do
          {:ok, info} ->
            setup_event_handlers(pid)
            Logger.info("Connected to Picopad on #{port}")

            {:ok,
             %State{
               picopad_pid: pid,
               port: port,
               status: connection_status(info.connection),
               player_number: info.player,
               last_error: nil
             }}

          {:error, reason} ->
            Logger.debug("#{port} did not respond as a Picopad: #{inspect(reason)}")
            Picopad.disconnect(pid)
            :error
        end

      {:error, reason} ->
        Logger.debug("Failed to open #{port}: #{inspect(reason)}")
        :error
    end
  end

  # A non-Picopad serial port (e.g. another USB-serial device) may never
  # reply, which makes the underlying GenServer.call exit. Catch that so a
  # single bad candidate can't crash the whole Connector.
  defp safe_status(pid) do
    Picopad.status(pid)
  catch
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp candidate_ports do
    case Circuits.UART.enumerate() do
      ports when is_map(ports) ->
        ports
        |> Map.keys()
        |> Enum.reject(&String.contains?(&1, "Bluetooth"))
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp setup_event_handlers(pid) do
    parent = self()

    handler = fn %{event: event, payload: payload} ->
      send(parent, {:picopad_event, event, payload})
    end

    Picopad.on_event(pid, :connection_changed, handler)
    Picopad.on_event(pid, :amiibo_scanned, handler)
    Picopad.on_event(pid, :log, handler)
  end

  defp connection_status(:disconnected), do: :connected
  defp connection_status(:advertising), do: :advertising
  defp connection_status(:pairing), do: :pairing
  defp connection_status(:ready), do: :paired
  defp connection_status(_), do: :connected
end
