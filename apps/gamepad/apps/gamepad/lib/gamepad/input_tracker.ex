defmodule Gamepad.InputTracker do
  use GenServer

  alias __MODULE__.State

  @name __MODULE__

  def start_link(arg) do
    GenServer.start_link(__MODULE__, [arg], name: @name)
  end

  def hold_buttons(tracker \\ @name, buttons) when is_binary(buttons) or is_list(buttons) do
    GenServer.cast(tracker, {:hold, List.wrap(buttons)})
  end

  def release_buttons(tracker \\ @name, buttons) when is_binary(buttons) or is_list(buttons) do
    GenServer.cast(tracker, {:release, List.wrap(buttons)})
  end

  ## GenServer

  @impl GenServer
  def init(_arg) do
    {:ok, State.new()}
  end

  @impl GenServer
  def handle_cast({:hold, buttons}, state) do
    new_state = State.hold_buttons(state, buttons)

    if new_state != state do
      send_inputs(new_state)
    end

    {:noreply, new_state}
  end

  def handle_cast({:release, buttons}, state) do
    new_state = State.release_buttons(state, buttons)

    if new_state != state do
      send_inputs(new_state)
    end

    {:noreply, new_state}
  end

  ## Helpers

  defp send_inputs(state = %State{}) do
    if Enum.empty?(state.held_buttons) do
      command = "release " <> Enum.join(State.all_buttons(), " ")
      Joycontrol.command(command)
    else
      command = "hold " <> Enum.join(state.held_buttons, " ")
      Joycontrol.command(command)
    end
  end
end
