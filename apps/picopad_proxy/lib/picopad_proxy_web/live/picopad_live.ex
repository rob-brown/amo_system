defmodule PicopadProxyWeb.PicopadLive do
  use PicopadProxyWeb, :live_view

  alias PicopadProxy.ConnectionManager

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PicopadProxy.PubSub, "picopad:connection")
    end

    available_ports = enumerate_ports()
    status = ConnectionManager.status()

    socket =
      socket
      |> assign(:available_ports, available_ports)
      |> assign(:selected_port, status.port)
      |> assign(:picopad_status, status.status)
      |> assign(:picopad_player, status.player_number)
      |> assign(:last_error, status.last_error)

    {:ok, socket}
  end

  @impl true
  def handle_event("select_port", %{"port" => ""}, socket) do
    IO.puts("Port selected: EMPTY")
    {:noreply, assign(socket, :selected_port, nil)}
  end

  @impl true
  def handle_event("select_port", %{"port" => port}, socket) do
    IO.puts("Port selected: #{port}")
    {:noreply, assign(socket, :selected_port, port)}
  end

  @impl true
  def handle_event("connect", _params, socket) do
    IO.puts("Connect clicked. selected_port = #{inspect(socket.assigns.selected_port)}")

    case socket.assigns.selected_port do
      nil ->
        {:noreply, put_flash(socket, :error, "Please select a port first")}

      "" ->
        {:noreply, put_flash(socket, :error, "Please select a port first")}

      port ->
        case ConnectionManager.connect(port) do
          :ok ->
            {:noreply, socket}

          {:error, reason} ->
            socket =
              socket
              |> put_flash(:error, "Failed to connect: #{inspect(reason)}")
              |> assign(:last_error, inspect(reason))

            {:noreply, socket}
        end
    end
  end

  @impl true
  def handle_event("disconnect", _params, socket) do
    ConnectionManager.disconnect()
    {:noreply, socket}
  end

  @impl true
  def handle_event("start_advertising", _params, socket) do
    case ConnectionManager.start_advertising() do
      :ok ->
        {:noreply, put_flash(socket, :info, "Started advertising")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to start advertising: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("stop_advertising", _params, socket) do
    case ConnectionManager.stop_advertising() do
      :ok ->
        {:noreply, put_flash(socket, :info, "Stopped advertising")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to stop advertising: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("forget_bonding", _params, socket) do
    case ConnectionManager.forget_bonding() do
      :ok ->
        {:noreply, put_flash(socket, :info, "Forgot bonding information")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to forget bonding: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("reconnect", _params, socket) do
    case ConnectionManager.reconnect() do
      :ok ->
        {:noreply, put_flash(socket, :info, "Reconnecting to Switch...")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to reconnect: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("refresh_ports", _params, socket) do
    available_ports = enumerate_ports()
    {:noreply, assign(socket, :available_ports, available_ports)}
  end

  @impl true
  def handle_info({:connection_changed, info}, socket) do
    socket =
      socket
      |> assign(:picopad_status, info.status)
      |> assign(:picopad_player, info.player_number)

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
            <dd class="mt-1 text-lg">
              <span class={status_badge_class(@picopad_status)}>
                {status_text(@picopad_status)}
              </span>
            </dd>
          </div>
          <%= if @picopad_player do %>
            <div>
              <dt class="text-sm font-medium text-gray-500">Player Number</dt>
              <dd class="mt-1 text-lg">Player {@picopad_player}</dd>
            </div>
          <% end %>
          <%= if @last_error do %>
            <div>
              <dt class="text-sm font-medium text-gray-500">Last Error</dt>
              <dd class="mt-1 text-sm text-red-600">{@last_error}</dd>
            </div>
          <% end %>
        </dl>
      </div>

      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <h2 class="text-2xl font-semibold mb-4">Serial Port</h2>
        <div class="space-y-4">
          <form phx-change="select_port">
            <label class="block text-sm font-medium text-gray-700 mb-2">Select Port</label>
            <select
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
              phx-click="refresh_ports"
              class="px-4 py-2 bg-gray-500 text-white rounded hover:bg-gray-600"
            >
              Refresh Ports
            </button>

            <%= if @picopad_status == :disconnected do %>
              <button
                phx-click="connect"
                class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
              >
                Connect
              </button>
            <% else %>
              <button
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
                phx-click="start_advertising"
                class="block w-full px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
              >
                Start Advertising
              </button>
            <% end %>

            <%= if @picopad_status == :advertising do %>
              <button
                phx-click="stop_advertising"
                class="block w-full px-4 py-2 bg-yellow-500 text-white rounded hover:bg-yellow-600"
              >
                Stop Advertising
              </button>
            <% end %>

            <button
              phx-click="forget_bonding"
              class="block w-full px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
            >
              Forget Bonding
            </button>

            <button
              phx-click="reconnect"
              class="block w-full px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
            >
              Reconnect to Switch
            </button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  defp enumerate_ports do
    case Circuits.UART.enumerate() do
      ports when is_map(ports) ->
        ports
        |> Enum.map(fn {port, _info} -> port end)
        |> Enum.reject(&String.contains?(&1, "Bluetooth"))
        |> Enum.sort()

      _ ->
        []
    end
  end

  defp status_text(:disconnected), do: "Disconnected"
  defp status_text(:connected), do: "Connected"
  defp status_text(:advertising), do: "Advertising"
  defp status_text(:pairing), do: "Pairing"
  defp status_text(:paired), do: "Paired"

  defp status_badge_class(:disconnected), do: "text-gray-500"
  defp status_badge_class(:connected), do: "text-blue-600"
  defp status_badge_class(:advertising), do: "text-yellow-600"
  defp status_badge_class(:pairing), do: "text-orange-600"
  defp status_badge_class(:paired), do: "text-green-600"
end
