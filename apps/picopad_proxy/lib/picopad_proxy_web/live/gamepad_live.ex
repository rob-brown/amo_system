defmodule PicopadProxyWeb.GamepadLive do
  use PicopadProxyWeb, :live_view

  alias PicopadProxy.UsbGamepad.Reader

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PicopadProxy.PubSub, "gamepad:events")
    end

    connected_gamepads = Reader.connected_gamepads()

    socket =
      socket
      |> assign(:connected_gamepads, connected_gamepads)

    {:ok, socket}
  end

  @impl true
  def handle_info({:gamepad_connected, info}, socket) do
    connected_gamepads = Map.put(socket.assigns.connected_gamepads, info.id, info.name)

    socket =
      socket
      |> assign(:connected_gamepads, connected_gamepads)
      |> put_flash(:info, "Gamepad connected: #{info.name}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:gamepad_disconnected, info}, socket) do
    connected_gamepads = Map.delete(socket.assigns.connected_gamepads, info.id)

    socket =
      socket
      |> assign(:connected_gamepads, connected_gamepads)
      |> put_flash(:info, "Gamepad disconnected: #{info.name}")

    {:noreply, socket}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <div class="mb-4">
        <.link navigate="/" class="text-blue-600 hover:text-blue-800">← Back to Home</.link>
      </div>

      <h1 class="text-4xl font-bold mb-8">USB Gamepad</h1>

      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <h2 class="text-2xl font-semibold mb-4">Connected Gamepads</h2>

        <%= if map_size(@connected_gamepads) == 0 do %>
          <p class="text-gray-500">No gamepads connected</p>
          <p class="text-sm text-gray-400 mt-2">
            Plug in a USB gamepad to get started. Supported controllers include Xbox, PlayStation, and Nintendo controllers.
          </p>
        <% else %>
          <div class="space-y-2">
            <%= for {id, name} <- @connected_gamepads do %>
              <div class="flex items-center justify-between p-4 bg-gray-50 rounded">
                <div>
                  <div class="font-medium">{name}</div>
                  <div class="text-sm text-gray-500">ID: {id}</div>
                </div>
                <span class="text-green-600">● Connected</span>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>

      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-2xl font-semibold mb-4">How It Works</h2>
        <div class="prose text-gray-700">
          <p>
            When you connect a USB gamepad, the Picopad Proxy automatically detects it and maps the buttons to Nintendo Switch controls:
          </p>
          <ul class="list-disc list-inside mt-2 space-y-1">
            <li>Face buttons (A/B/X/Y) are mapped to Switch equivalents</li>
            <li>D-pad controls the directional buttons</li>
            <li>Analog sticks control the Switch left/right sticks</li>
            <li>Shoulder buttons (L/R/ZL/ZR) work as expected</li>
            <li>Start/Select map to Plus/Minus</li>
          </ul>
          <p class="mt-4">
            The gamepad input is automatically forwarded to the connected Picopad, which then sends it to your Nintendo Switch.
          </p>
        </div>
      </div>
    </div>
    """
  end
end
