defmodule UiWeb.ProxyLive do
  use UiWeb, :live_view

  require Logger

  @button_names ~w"a b y x l zl r zr l_stick r_stick plus minus home capture"

  # TODO: Handle axes too.

  @impl true
  def mount(_params, _session, socket) do
    assigns = [
      device: nil,
      code_mapping: nil,
      button_mapping: nil,
      capabilities: nil,
      device_list: fetch_devices(),
      action: "connect"
    ]

    socket = assign(socket, assigns)
    {:ok, socket}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    device_list = fetch_devices()
    socket = assign(socket, device_list: device_list)

    {:noreply, socket}
  end

  def handle_event("connect", %{"form" => %{"path" => path}}, socket) do
    case Proxy.connect(path) do
      {:connected, device, mapping} ->
        capabilities = Proxy.capabilities(path)
        button_mapping = convert_mapping(mapping)

        socket =
          assign(socket,
            device: device,
            button_mapping: button_mapping,
            code_mapping: mapping,
            capabilities: capabilities,
            action: "configure"
          )

        {:noreply, socket}

      {:error, reason} ->
        Logger.error(reason)
        {:noreply, socket}
    end
  end

  def handle_event("disconnect", _params, socket) do
    Proxy.disconnect()
    socket = assign(socket, device: nil, action: "connect")

    {:noreply, socket}
  end

  def handle_event("configure", %{"form" => params}, socket) do
    button_params = Map.take(params, @button_names)

    buttons =
      Map.new(button_params, fn {name, event} ->
        {String.to_integer(event), {:button, name}}
      end)

    new_mapping = Map.merge(socket.assigns.code_mapping, buttons)

    Proxy.set_mapping(new_mapping)

    socket = assign(socket, button_mapping: button_params)

    {:noreply, socket}
  end

  def handle_event(event, params, socket) do
    Logger.warning("Unhandled event #{event} with #{inspect(params)}")

    {:noreply, socket}
  end

  @impl true
  def handle_info(:check_connection, socket) do
    {:noreply, socket}
  end

  defp convert_mapping(mapping) do
    for {event, {_type, name}} <- mapping, into: %{} do
      {name, event}
    end
  end

  defp device_options(device_list) do
    for %{"name" => name, "path" => path} <- device_list do
      {name, path}
    end
  end

  defp button_options(code_mapping, capabilities) do
    for {code, index} <- Enum.with_index(capabilities["buttons"]) do
      string = to_string(code)

      case code_mapping[code] do
        {:button, name} ->
          {"#{text_label(name)} (#{string})", string}

        _ ->
          {"Button #{index} (#{string})", string}
      end
    end
  end

  defp button_info(button_mapping, code_mapping, capabilities) do
    options = button_options(code_mapping, capabilities)

    for button <- @button_names do
      %{
        label: text_label(button),
        key: String.to_atom(button),
        value: button_mapping[button],
        options: options
      }
    end
  end

  defp fetch_devices() do
    # I don't know what vc4 is but don't show it.
    Enum.reject(Proxy.list_devices(), & &1["name"] == "vc4")
  end

  defp text_label("l"), do: text_label("l / l1 / lb")
  defp text_label("r"), do: text_label("r / r1 / rb")
  defp text_label("zl"), do: text_label("zl / l2 / lt")
  defp text_label("zr"), do: text_label("zr / r2 / rt")
  defp text_label("l_stick"), do: text_label("l stick / l3")
  defp text_label("r_stick"), do: text_label("r stick / r3")

  defp text_label(button) do
    String.upcase(button)
  end
end
