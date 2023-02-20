defmodule UiWeb.BluetoothLive do
  use UiWeb, :live_view

  require Logger

  alias Gamepad.Bluetooth

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      info: "",
      paired_devices: [],
      connected?: false
    ]

    socket = update_state(socket, assigns)
    refresh()

    Process.send_after(self(), :check_connection, :timer.seconds(1))

    {:ok, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    refresh()
    {:noreply, socket}
  end

  def handle_event("pair_and_connect", _, socket) do
    Bluetooth.pair_and_connect()
    {:noreply, socket}
  end

  def handle_event("connect", %{"mac" => mac}, socket) do
    Bluetooth.reconnect("auto")
    {:noreply, socket}
  end

  def handle_event("disconnect", _, socket) do
    Bluetooth.disconnect()
    {:noreply, socket}
  end

  def handle_event("reset", _, socket) do
    Bluetooth.unpair_all()
    Bluetooth.disconnect()
    refresh()
    {:noreply, socket}
  end

  def handle_event("reboot", _, socket) do
    System.cmd("sudo", ["reboot"])
    {:noreply, socket}
  end

  def handle_event("unpair", %{"mac" => mac}, socket) do
    Bluetooth.unpair(mac)

    spawn(fn ->
      Process.sleep(1000)
      refresh()
    end)

    {:noreply, socket}
  end

  def handle_event(event, params, socket) do
    Logger.warn("Unhandled event '#{event}' with params #{inspect(params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info(:check_connection, socket) do
    Process.send_after(self(), :check_connection, :timer.seconds(1))
    socket = update_state(socket, [])
    {:noreply, socket}
  end

  def handle_info({:refresh_info, info}, socket) do
    socket = update_state(socket, info: info)
    {:noreply, socket}
  end

  @impl true
  def handle_info({:refresh_devices, devices}, socket) do
    socket = update_state(socket, paired_devices: devices)
    {:noreply, socket}
  end

  defp refresh() do
    me = self()

    spawn(fn ->
      {:ok, info} = Bluetooth.info()
      send(me, {:refresh_info, info})
    end)

    spawn(fn ->
      {:ok, devices} = Bluetooth.paired_devices()
      send(me, {:refresh_devices, devices})
    end)
  end

  defp update_state(socket, assigns) do
    connected? = Gamepad.Joycontrol.running?()

    [{:connected?, connected?} | assigns]
    |> Enum.reduce(socket, fn {k, v}, socket ->
      assign(socket, k, v)
    end)
  end
end
