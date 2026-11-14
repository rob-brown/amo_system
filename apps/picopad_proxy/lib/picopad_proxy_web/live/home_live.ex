defmodule PicopadProxyWeb.HomeLive do
  use PicopadProxyWeb, :live_view

  alias PicopadProxy.ConnectionManager
  alias PicopadProxyWeb.PicopadStatus

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PicopadProxy.PubSub, "picopad:connection")
      Phoenix.PubSub.subscribe(PicopadProxy.PubSub, "gamepad:events")
    end

    status = ConnectionManager.status()
    gamepads = PicopadProxy.UsbGamepad.Reader.connected_gamepads()

    socket =
      socket
      |> assign_device(status)
      |> assign(:gamepad_connected, map_size(gamepads) > 0)

    {:ok, socket}
  end

  @impl true
  def handle_info({:connection_changed, info}, socket) do
    {:noreply, assign_device(socket, info)}
  end

  @impl true
  def handle_info({:gamepad_connected, _info}, socket) do
    {:noreply, assign(socket, :gamepad_connected, true)}
  end

  @impl true
  def handle_info({:gamepad_disconnected, _info}, socket) do
    {:noreply, assign(socket, :gamepad_connected, false)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <h1 class="text-4xl font-bold mb-8">Picopad Proxy</h1>

      <div class="grid grid-cols-1 md:grid-cols-2 gap-6 mb-8">
        <div class="bg-white shadow rounded-lg p-6">
          <h2 class="text-2xl font-semibold mb-4">Picopad Status</h2>
          <dl class="space-y-2">
            <div>
              <dt class="text-sm font-medium text-gray-500">Connection</dt>
              <dd id="home-picopad-status" class="mt-1 text-lg">
                <span class={PicopadStatus.status_badge_class(@picopad_status)}>
                  {PicopadStatus.status_text(@picopad_status)}
                </span>
              </dd>
            </div>
            <%= if @picopad_firmware do %>
              <div>
                <dt class="text-sm font-medium text-gray-500">Device</dt>
                <dd id="home-picopad-firmware" class="mt-1 text-lg">
                  {PicopadStatus.firmware_text(@picopad_firmware)}
                </dd>
              </div>
              <div>
                <dt class="text-sm font-medium text-gray-500">Player</dt>
                <dd id="home-picopad-player" class="mt-1 text-lg">
                  {PicopadStatus.player_text(@picopad_player)}
                </dd>
              </div>
            <% end %>
            <%= if @picopad_port do %>
              <div>
                <dt class="text-sm font-medium text-gray-500">Port</dt>
                <dd class="mt-1 text-lg">{@picopad_port}</dd>
              </div>
            <% end %>
            <%= if @picopad_error do %>
              <div>
                <dt class="text-sm font-medium text-gray-500">Last Error</dt>
                <dd id="home-picopad-error" class="mt-1 text-sm text-red-600">{@picopad_error}</dd>
              </div>
            <% end %>
          </dl>
          <div class="mt-4">
            <.link navigate="/picopad" class="text-blue-600 hover:text-blue-800">
              Manage Picopad →
            </.link>
          </div>
        </div>

        <div class="bg-white shadow rounded-lg p-6">
          <h2 class="text-2xl font-semibold mb-4">USB Gamepad</h2>
          <dl class="space-y-2">
            <div>
              <dt class="text-sm font-medium text-gray-500">Status</dt>
              <dd class="mt-1 text-lg">
                <span class={if @gamepad_connected, do: "text-green-600", else: "text-gray-500"}>
                  {if @gamepad_connected, do: "Connected", else: "Not Connected"}
                </span>
              </dd>
            </div>
          </dl>
          <div class="mt-4">
            <.link navigate="/gamepad" class="text-blue-600 hover:text-blue-800">
              Manage Gamepad →
            </.link>
          </div>
        </div>
      </div>

      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-2xl font-semibold mb-4">Quick Actions</h2>
        <div class="space-y-2">
          <.link
            navigate="/picopad"
            class="block px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
          >
            Connect to Picopad
          </.link>
          <.link
            navigate="/amiibo"
            class="block px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
          >
            Manage Amiibo
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp assign_device(socket, info) do
    socket
    |> assign(:picopad_status, info.status)
    |> assign(:picopad_port, info.port)
    |> assign(:picopad_player, info.player_number)
    |> assign(:picopad_firmware, info.firmware)
    |> assign(:picopad_error, info.last_error)
  end
end
