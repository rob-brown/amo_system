defmodule Gamepad.InputTracker.State do
  @all_buttons ~w"a b x y up down left right home capture minus plus r zr l zl l_stick r_stick"

  # @stick_min 0
  @stick_middle 2048
  @stick_max 4096

  @enforce_keys [:held_buttons, :released_buttons, :buttons_changed, :sticks, :last_stick_report]
  defstruct [:held_buttons, :released_buttons, :buttons_changed, :sticks, :last_stick_report]

  def new() do
    %__MODULE__{
      held_buttons: MapSet.new(),
      released_buttons: MapSet.new(@all_buttons),
      buttons_changed: false,
      last_stick_report: now(),
      sticks: %{
        left: %{h: @stick_middle, v: @stick_middle, changed: false},
        right: %{h: @stick_middle, v: @stick_middle, changed: false}
      }
    }
  end

  def all_buttons() do
    @all_buttons
  end

  def hold_buttons(state = %__MODULE__{}, []) do
    state
  end

  def hold_buttons(state = %__MODULE__{}, [button | rest]) when button in @all_buttons do
    new_state = %__MODULE__{
      state
      | held_buttons: MapSet.put(state.held_buttons, button),
        released_buttons: MapSet.delete(state.released_buttons, button),
        buttons_changed: true
    }

    hold_buttons(new_state, rest)
  end

  def release_buttons(state = %__MODULE__{}, []) do
    state
  end

  def release_buttons(state = %__MODULE__{}, [button | rest]) when button in @all_buttons do
    new_state = %__MODULE__{
      state
      | released_buttons: MapSet.put(state.released_buttons, button),
        held_buttons: MapSet.delete(state.held_buttons, button),
        buttons_changed: true
    }

    release_buttons(new_state, rest)
  end

  def move_stick(state = %__MODULE__{}, stick, {direction, magnitude}, {min, max, deadzone})
      when stick in [:left, :right] and direction in [:h, :v] do
    middle = div(max - min, 2)

    value =
      cond do
        magnitude > middle + deadzone ->
          translate(magnitude, min, max, direction == :v)

        magnitude < middle - deadzone ->
          translate(magnitude, min, max, direction == :v)

        true ->
          @stick_middle
      end

    sticks =
      state.sticks
      |> put_in([stick, direction], value)
      |> put_in([stick, :changed], true)

    %__MODULE__{state | sticks: sticks}
  end

  defp translate(magnitude, min, max, invert?) do
    # Shift the range from 0-max if not already
    range = max - min

    value =
      if invert? do
        max - magnitude - min
      else
        magnitude - min
      end

    # Avoid division by 0
    if value == 0 do
      0
    else
      # Map to Joycontrol range.
      percent = value / range
      trunc(@stick_max * percent)
    end
  end

  def button_commands(state = %__MODULE__{}) do
    commands =
      cond do
        state.buttons_changed == false ->
          []

        Enum.empty?(state.held_buttons) ->
          ["release " <> Enum.join(@all_buttons, " ")]

        true ->
          ["hold " <> Enum.join(state.held_buttons, " ")]
      end

    new_state = %__MODULE__{state | buttons_changed: false}

    {commands, new_state}
  end

  @update_interval_ms 1

  def stick_commands(state = %__MODULE__{}) do
    now = now()

    if now - state.last_stick_report > @update_interval_ms do
      commands =
        for {side, info} <- state.sticks,
            info.changed == true,
            {axis, value} <- info,
            axis in [:h, :v] do
          "stick #{side} #{axis} #{value}"
        end

      sticks =
        state.sticks
        |> put_in([:left, :changed], false)
        |> put_in([:right, :changed], false)

      new_state = %__MODULE__{state | last_stick_report: now, sticks: sticks}

      {commands, new_state}
    else
      {[], state}
    end
  end

  defp now() do
    :erlang.monotonic_time(:millisecond)
  end
end
