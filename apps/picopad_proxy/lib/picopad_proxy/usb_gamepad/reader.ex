defmodule PicopadProxy.UsbGamepad.Reader do
  use GenServer

  require Logger

  alias PicopadProxy.UsbGamepad.EventProcessor

  @poll_interval 10

  defmodule State do
    @enforce_keys [:gilrs]
    defstruct [:gilrs, :connected_gamepads]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def connected_gamepads do
    GenServer.call(__MODULE__, :connected_gamepads)
  end

  @impl true
  def init(_opts) do
    case GilrsEx.new() do
      {:ok, gilrs} ->
        send(self(), :poll_events)
        {:ok, %State{gilrs: gilrs, connected_gamepads: %{}}}

      {:error, reason} ->
        Logger.error("Failed to initialize GilRs: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:connected_gamepads, _from, state) do
    {:ok, gamepad_ids} = GilrsEx.connected_gamepads(state.gilrs)

    gamepads =
      for id <- gamepad_ids, into: %{} do
        {:ok, name} = GilrsEx.gamepad_name(state.gilrs, id)
        {id, name}
      end

    {:reply, gamepads, state}
  end

  @impl true
  def handle_info(:poll_events, state) do
    case GilrsEx.next_event(state.gilrs) do
      {:ok, event} ->
        controller_name = Map.get(state.connected_gamepads, event.gamepad_id)
        EventProcessor.process_event(event, controller_name)
        send(self(), :poll_events)
        {:noreply, handle_gamepad_event(event, state)}

      :none ->
        Process.send_after(self(), :poll_events, @poll_interval)
        {:noreply, state}
    end
  end

  defp handle_gamepad_event(%{event_type: "connected", gamepad_id: id}, state) do
    {:ok, name} = GilrsEx.gamepad_name(state.gilrs, id)
    Logger.info("Gamepad connected: #{name} (ID: #{id})")

    Phoenix.PubSub.broadcast(
      PicopadProxy.PubSub,
      "gamepad:events",
      {:gamepad_connected, %{id: id, name: name}}
    )

    %State{state | connected_gamepads: Map.put(state.connected_gamepads, id, name)}
  end

  defp handle_gamepad_event(%{event_type: "disconnected", gamepad_id: id}, state) do
    name = Map.get(state.connected_gamepads, id, "Unknown")
    Logger.info("Gamepad disconnected: #{name} (ID: #{id})")

    Phoenix.PubSub.broadcast(
      PicopadProxy.PubSub,
      "gamepad:events",
      {:gamepad_disconnected, %{id: id, name: name}}
    )

    %State{state | connected_gamepads: Map.delete(state.connected_gamepads, id)}
  end

  defp handle_gamepad_event(_event, state), do: state
end
