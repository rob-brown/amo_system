defmodule PicopadProxy.InputTracker do
  use GenServer

  alias PicopadProxy.ConnectionManager
  alias PicopadProxy.InputTracker.State

  @name __MODULE__

  def start_link(arg) do
    GenServer.start_link(__MODULE__, [arg], name: @name)
  end

  def hold_buttons(buttons, opts \\ []) when is_binary(buttons) or is_list(buttons) do
    GenServer.cast(@name, {:update_buttons, List.wrap(buttons), [], opts})
  end

  def release_buttons(buttons, opts \\ []) when is_binary(buttons) or is_list(buttons) do
    GenServer.cast(@name, {:update_buttons, [], List.wrap(buttons), opts})
  end

  def update_buttons(pressed, released, opts \\ [])
      when is_binary(pressed) or (is_list(pressed) and is_binary(released)) or is_list(released) do
    GenServer.cast(@name, {:update_buttons, List.wrap(pressed), List.wrap(released), opts})
  end

  def move_stick(stick, position, config, opts \\ []) do
    GenServer.cast(@name, {:stick, stick, position, config, opts})
  end

  def report(tracker \\ @name) do
    GenServer.cast(tracker, :report)
  end

  @impl GenServer
  def init(_arg) do
    {:ok, State.new()}
  end

  @impl GenServer
  def handle_cast({:update_buttons, pressed, released, opts}, state) do
    new_state =
      state
      |> State.hold_buttons(pressed)
      |> State.release_buttons(released)

    report? = Keyword.get(opts, :report, true)

    if report? and new_state != state do
      {:noreply, send_inputs(new_state)}
    else
      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_cast({:stick, stick, position, config, opts}, state) do
    new_state = State.move_stick(state, stick, position, config)
    report? = Keyword.get(opts, :report, true)

    if report? and new_state != state do
      {:noreply, send_inputs(new_state)}
    else
      {:noreply, new_state}
    end
  end

  @impl GenServer
  def handle_cast(:report, state) do
    {:noreply, send_inputs(state)}
  end

  defp send_inputs(state = %State{}) do
    case ConnectionManager.picopad_pid() do
      nil ->
        state

      pid ->
        state = send_button_inputs(pid, state)
        state = send_stick_inputs(pid, state)
        state
    end
  end

  defp send_button_inputs(pid, state) do
    if state.buttons_changed do
      buttons = MapSet.to_list(state.held_buttons)
      button_atoms = Enum.map(buttons, &String.to_atom/1)

      if Enum.empty?(button_atoms) do
        Picopad.release_all(pid)
      else
        Picopad.hold(pid, button_atoms)
      end

      %State{state | buttons_changed: false}
    else
      state
    end
  end

  defp send_stick_inputs(pid, state) do
    now = :erlang.monotonic_time(:millisecond)
    update_all? = now - state.last_stick_report > 20

    sticks_to_update =
      for {side, info} <- state.sticks,
          info.changed == true,
          update_all? or (info.h == 2048 and info.v == 2048) do
        {side, info}
      end

    if length(sticks_to_update) > 0 do
      for {side, info} <- sticks_to_update do
        # Picopad expects raw 12-bit Pro Controller values (0-4095), not signed values
        # Just clamp to valid range and invert Y-axis
        x = min(max(info.h, 0), 4095)
        y = 4095 - min(max(info.v, 0), 4095)

        Picopad.stick(pid, side, {x, y})
      end

      sticks =
        state.sticks
        |> put_in([:left, :changed], false)
        |> put_in([:right, :changed], false)

      %State{state | sticks: sticks, last_stick_report: now}
    else
      state
    end
  end
end
