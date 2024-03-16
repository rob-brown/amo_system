defmodule Gamepad.InputTracker do
  use GenServer

  alias __MODULE__.State

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

  ## GenServer

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
    end

    {:noreply, new_state}
  end

  def handle_cast({:stick, stick, position, config, opts}, state) do
    new_state = State.move_stick(state, stick, position, config)
    report? = Keyword.get(opts, :report, true)

    if report? and new_state != state do
      {:noreply, send_inputs(new_state)}
    end

    {:noreply, new_state}
  end

  def handle_cast(:report, state) do
    {:noreply, send_inputs(state)}
  end

  ## Helpers

  defp send_inputs(state = %State{}) do
    {button_commands, state} = State.button_commands(state)
    {stick_commands, state} = State.stick_commands(state)

    commands = button_commands ++ stick_commands

    commands
    |> Enum.join(" && ")
    |> case do
      "" -> :ok
      command -> Joycontrol.command(command)
    end

    state
  end
end
