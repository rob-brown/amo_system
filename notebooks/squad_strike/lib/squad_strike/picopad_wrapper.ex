defmodule SquadStrike.PicopadWrapper do
  @moduledoc """
  Creates a singleton instance of Picopad for use with Autopilot.
  """

  use GenServer
  @behaviour Autopilot.Gamepad

  @name __MODULE__

  def start_link(device) do
    # ???: Should I watch the connection status and try to reconnect?
    GenServer.start_link(__MODULE__, device, name: @name)
  end

  def stop() do
    if Process.whereis(@name) do
      GenServer.call(@name, :disconnect)
      GenServer.stop(@name)
    end
  end

  def init(device) do
    {:ok, _pid} = Picopad.connect(device)
  end

  def press(button) do
    press(button, 100)
  end

  def press(button, duration) when is_atom(button) do
    GenServer.cast(@name, {:press, button, duration})
  end

  def press(button, duration) when is_binary(button) do
    button = String.to_atom(button)
    press(button, duration)
  end

  def load_amiibo(binary) do
    GenServer.cast(@name, {:load_amiibo, binary})
  end

  def clear_amiibo() do
    GenServer.cast(@name, :clear_amiibo)
  end

  def handle_cast({:press, button, duration}, pid) do
    Picopad.press(pid, button, duration)
    {:noreply, pid}
  end

  def handle_cast({:load_amiibo, binary}, pid) do
    Picopad.load_amiibo(pid, binary)
    {:noreply, pid}
  end

  def handle_cast(:clear_amiibo, pid) do
    Picopad.clear_amiibo(pid)
    {:noreply, pid}
  end

  def handle_call(:disconnect, _from, pid) do
    Picopad.disconnect(pid)
    {:reply, :ok, pid}
  end
end
