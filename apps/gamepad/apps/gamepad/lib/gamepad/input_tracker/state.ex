defmodule Gamepad.InputTracker.State do
  @all_buttons ~w"a b x y up down left right home capture minus plus r zr l zl l_stick r_stick"

  @enforce_keys [:held_buttons, :released_buttons]
  defstruct [:held_buttons, :released_buttons]

  def new() do
    %__MODULE__{held_buttons: MapSet.new(), released_buttons: MapSet.new(@all_buttons)}
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
        released_buttons: MapSet.delete(state.released_buttons, button)
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
        held_buttons: MapSet.delete(state.held_buttons, button)
    }

    release_buttons(new_state, rest)
  end
end
