defmodule PicopadProxyWeb.PicopadLive do
  use PicopadProxyWeb, :live_view

  alias PicopadProxy.ConnectionManager
  alias PicopadProxy.Errors
  alias PicopadProxyWeb.PicopadStatus

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PicopadProxy.PubSub, "picopad:connection")
    end

    status = ConnectionManager.status()

    socket =
      socket
      |> assign(:available_ports, enumerate_ports())
      |> assign(:selected_port, status.port)
      |> assign(:detecting, false)
      |> assign_device(status)
      |> detect_on_mount(status)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_port", %{"port" => ""}, socket) do
    {:noreply, assign(socket, :selected_port, nil)}
  end

  def handle_event("select_port", %{"port" => port}, socket) do
    {:noreply, assign(socket, :selected_port, port)}
  end

  def handle_event("connect", _params, %{assigns: %{selected_port: nil}} = socket) do
    {:noreply, put_flash(socket, :error, "Please select a port first")}
  end

  def handle_event("connect", _params, socket) do
    case ConnectionManager.connect(socket.assigns.selected_port) do
      :ok ->
        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to connect: #{Errors.message(reason)}")}
    end
  end

  def handle_event("detect", _params, socket) do
    {:noreply, start_detect(socket, :detect)}
  end

  def handle_event("disconnect", _params, socket) do
    ConnectionManager.disconnect()
    {:noreply, socket}
  end

  def handle_event("start_advertising", _params, socket) do
    run_command(socket, &ConnectionManager.start_advertising/0, "Started advertising")
  end

  def handle_event("stop_advertising", _params, socket) do
    run_command(socket, &ConnectionManager.stop_advertising/0, "Stopped advertising")
  end

  def handle_event("forget_bonding", _params, socket) do
    run_command(socket, &ConnectionManager.forget_bonding/0, "Forgot bonding information")
  end

  def handle_event("reconnect", _params, socket) do
    run_command(socket, &ConnectionManager.reconnect/0, "Reconnecting to the console...")
  end

  def handle_event("refresh_ports", _params, socket) do
    {:noreply, assign(socket, :available_ports, enumerate_ports())}
  end

  @impl true
  def handle_async(name, {:ok, :ok}, socket) when name in [:detect, :auto_detect] do
    status = ConnectionManager.status()

    socket =
      socket
      |> assign(:detecting, false)
      |> assign(:selected_port, status.port)
      |> assign_device(status)

    {:noreply, socket}
  end

  def handle_async(:auto_detect, {:ok, {:error, :not_found}}, socket) do
    {:noreply, assign(socket, :detecting, false)}
  end

  def handle_async(_name, {:ok, {:error, reason}}, socket) do
    socket =
      socket
      |> assign(:detecting, false)
      |> put_flash(:error, "Detection failed: #{Errors.message(reason)}")

    {:noreply, socket}
  end

  def handle_async(_name, {:exit, reason}, socket) do
    socket =
      socket
      |> assign(:detecting, false)
      |> put_flash(:error, "Detection failed: #{Errors.message(reason)}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:connection_changed, info}, socket) do
    {:noreply, assign_device(socket, info)}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <div class="mb-4">
        <.link navigate="/" class="text-blue-600 hover:text-blue-800">← Back to Home</.link>
      </div>

      <h1 class="text-4xl font-bold mb-8">Picopad Connection</h1>

      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <h2 class="text-2xl font-semibold mb-4">Current Status</h2>
        <dl class="space-y-2">
          <div>
            <dt class="text-sm font-medium text-gray-500">Connection</dt>
            <dd id="picopad-status" class="mt-1 text-lg">
              <span class={PicopadStatus.status_badge_class(@picopad_status)}>
                {PicopadStatus.status_text(@picopad_status)}
              </span>
            </dd>
          </div>
          <%= if @picopad_firmware do %>
            <div>
              <dt class="text-sm font-medium text-gray-500">Device</dt>
              <dd id="picopad-firmware" class="mt-1 text-lg">
                {PicopadStatus.firmware_text(@picopad_firmware)}
                <span :if={PicopadStatus.controller_text(@picopad_controller)} class="text-gray-500">
                  · {PicopadStatus.controller_text(@picopad_controller)}
                </span>
              </dd>
            </div>
            <div>
              <dt class="text-sm font-medium text-gray-500">Player Number</dt>
              <dd id="picopad-player" class="mt-1 text-lg">
                {PicopadStatus.player_text(@picopad_player)}
              </dd>
            </div>
          <% end %>
          <%= if @last_error do %>
            <div>
              <dt class="text-sm font-medium text-gray-500">Last Error</dt>
              <dd id="picopad-error" class="mt-1 text-sm text-red-600">{@last_error}</dd>
            </div>
          <% end %>
        </dl>
      </div>

      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <h2 class="text-2xl font-semibold mb-4">Serial Port</h2>
        <div class="space-y-4">
          <form id="port-form" phx-change="select_port">
            <label class="block text-sm font-medium text-gray-700 mb-2">Select Port</label>
            <select
              id="port-select"
              name="port"
              class="block w-full px-3 py-2 border border-gray-300 rounded-md"
            >
              <%= if @selected_port == nil do %>
                <option value="" selected disabled>-- Select a port --</option>
              <% end %>
              <%= for port <- @available_ports do %>
                <option value={port} selected={port == @selected_port}>{port}</option>
              <% end %>
            </select>
          </form>

          <div class="flex gap-2">
            <button
              id="refresh-ports"
              phx-click="refresh_ports"
              class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600"
            >
              Refresh Ports
            </button>

            <%= if @picopad_status == :disconnected do %>
              <button
                id="detect"
                phx-click="detect"
                disabled={@detecting}
                class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600 disabled:opacity-50"
              >
                {if @detecting, do: "Detecting...", else: "Detect"}
              </button>
              <button
                id="connect"
                phx-click="connect"
                class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
              >
                Connect
              </button>
            <% else %>
              <button
                id="disconnect"
                phx-click="disconnect"
                class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
              >
                Disconnect
              </button>
            <% end %>
          </div>
        </div>
      </div>

      <%= if @picopad_status != :disconnected do %>
        <div class="bg-white shadow rounded-lg p-6">
          <h2 class="text-2xl font-semibold mb-4">Bluetooth Controls</h2>
          <div class="space-y-2">
            <%= if @picopad_status == :connected do %>
              <button
                id="start-advertising"
                phx-click="start_advertising"
                class="block w-full px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
              >
                Start Advertising
              </button>
            <% end %>

            <%= if @picopad_status == :advertising do %>
              <button
                id="stop-advertising"
                phx-click="stop_advertising"
                class="block w-full px-4 py-2 bg-yellow-500 text-white rounded hover:bg-yellow-600"
              >
                Stop Advertising
              </button>
            <% end %>

            <button
              id="forget-bonding"
              phx-click="forget_bonding"
              class="block w-full px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
            >
              Forget Bonding
            </button>

            <button
              id="reconnect"
              phx-click="reconnect"
              class="block w-full px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              Reconnect to Console
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp assign_device(socket, info) do
    socket
    |> assign(:picopad_status, info.status)
    |> assign(:picopad_player, info.player_number)
    |> assign(:picopad_firmware, info.firmware)
    |> assign(:picopad_controller, info.controller)
    |> assign(:last_error, info.last_error)
  end

  defp detect_on_mount(socket, %{status: :disconnected}) do
    if connected?(socket) and Application.get_env(:picopad_proxy, :auto_connect, true) do
      start_detect(socket, :auto_detect)
    else
      socket
    end
  end

  defp detect_on_mount(socket, _status), do: socket

  defp start_detect(socket, name) do
    socket
    |> assign(:detecting, true)
    |> start_async(name, fn -> ConnectionManager.auto_connect() end)
  end

  defp run_command(socket, command, success_message) do
    case command.() do
      :ok ->
        {:noreply, put_flash(socket, :info, success_message)}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed: #{Errors.message(reason)}")}
    end
  end

  defp enumerate_ports do
    case Circuits.UART.enumerate() do
      ports when is_map(ports) ->
        ports
        |> Enum.reject(fn {port, _info} -> String.contains?(port, "Bluetooth") end)
        |> Enum.map(fn {port, _info} -> port end)
        |> Enum.sort()

      _ ->
        []
    end
  end
end
