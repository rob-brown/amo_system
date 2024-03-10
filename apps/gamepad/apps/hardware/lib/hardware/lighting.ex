defmodule Hardware.Lighting do
  use GenServer

  alias Hardware.Lighting.Strategy

  @name __MODULE__

  defstruct [:leds, :strategy, :timer]

  def blink(delay \\ 500, peak \\ 255) do
    Strategy.blink(delay, peak)
    |> change_strategy()
  end

  def pulse(delay \\ 500) do
    Strategy.pulse(delay)
    |> change_strategy()
  end

  def on(peak \\ 128) do
    Strategy.on(peak)
    |> change_strategy()
  end

  def off() do
    Strategy.off()
    |> change_strategy()
  end

  def change_strategy(strategy) when is_function(strategy, 1) do
    GenServer.cast(@name, {:change_strategy, strategy})
  end

  ## GenServer

  def start_link(args) do
    GenServer.start_link(__MODULE__, [args], name: @name)
  end

  def init(_) do
    leds =
      for p <- [21, 20, 24, 23, 18] do
        Hardware.Lighting.LED.new(p)
      end

    state = %__MODULE__{leds: leds, strategy: nil, timer: nil}
    {:ok, state}
  end

  def handle_cast({:change_strategy, strategy}, state) do
    cancel_timer(state)
    new_state = %__MODULE__{state | strategy: strategy}

    {:noreply, tick(new_state)}
  end

  def handle_info(:tick, state) do
    {:noreply, tick(state)}
  end

  defp tick(state) do
    {new_leds, delay} = state.strategy.(state.leds)
    timer = :timer.send_after(delay, :tick)
    %__MODULE__{state | timer: timer, leds: new_leds}
  end

  defp cancel_timer(%__MODULE__{timer: nil}) do
    :ok
  end

  defp cancel_timer(%__MODULE__{timer: timer}) do
    :timer.cancel(timer)
  end
end
