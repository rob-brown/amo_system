defmodule UiWeb.ProxyLive do
  use UiWeb, :live_view

  require Logger

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      devices: Proxy.list_devices(),
      input_path: nil
    ]

    socket = update_state(socket, assigns)
    {:ok, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do

    {:noreply, socket}
  end

  @impl true
  def handle_info(:check_connection, socket) do
    {:noreply, socket}
  end
end

