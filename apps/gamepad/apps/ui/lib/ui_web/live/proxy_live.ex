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
      axis_mapping: nil,
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
        button_mapping = convert_button_mapping(mapping)
        axis_mapping = convert_axis_mapping(mapping)

        socket =
          assign(socket,
            device: device,
            button_mapping: button_mapping,
            axis_mapping: axis_mapping,
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

    # Create the button mapping but skip any unset buttons.
    buttons =
      button_params
      |> Enum.reject(&match?({_name, ""}, &1))
      |> Map.new(fn {name, event} ->
        {String.to_integer(event), {:button, name}}
      end)

    axes =
      for {type, name} <- [{:stick, "left"}, {:stick, "right"}, {:pad, "dpad"}] do
        x_code = params[name <> "_x"] |> to_int()
        y_code = params[name <> "_y"] |> to_int()
        min = params[name <> "_min"] |> to_int()
        max = params[name <> "_max"] |> to_int()
        deadzone = params[name <> "_deadzone"] |> to_int()
        x = String.slice(name, 0..0) <> "x"
        y = String.slice(name, 0..0) <> "y"

        [
          {x_code, {type, x, min, max, deadzone}},
          {y_code, {type, y, min, max, deadzone}}
        ]
      end
      |> List.flatten()
      |> Map.new()

    new_mapping =
      socket.assigns.code_mapping
      |> Map.merge(buttons)
      |> Map.merge(axes)
      |> IO.inspect(label: :config)

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

  defp convert_button_mapping(mapping) do
    for {event, {_type, name}} <- mapping, into: %{} do
      {name, event}
    end
  end

  defp convert_axis_mapping(mapping) do
    for {event, {_type, name, _min, _max, _deadzone}} <- mapping, into: %{} do
      {name, event}
    end
  end

  defp device_options(device_list) do
    for %{"name" => name, "path" => path} <- device_list do
      {name, path}
    end
  end

  defp axis_options(code_mapping, capabilities) do
    for {info, index} <- Enum.with_index(capabilities["axes"]) do
      %{"code" => code} = info
      string = to_string(code)

      case code_mapping[code] do
        {:stick, name, _min, _max, _deadzone} ->
          {"#{text_label(name)} (#{string})", string}

        {:pad, name, _min, _max, _deadzone} ->
          {"#{text_label(name)} (#{string})", string}

        _ ->
          {"Axis #{index} (#{string})", string}
      end
    end
  end

  defp axis_info(:left, axis_mapping, code_mapping, capabilities) do
    %{
      name: "Left Stick",
      key: "left",
      x: axis_info("lx", axis_mapping, code_mapping, capabilities),
      y: axis_info("ly", axis_mapping, code_mapping, capabilities)
    }
  end

  defp axis_info(:right, axis_mapping, code_mapping, capabilities) do
    %{
      name: "Right Stick",
      key: "right",
      x: axis_info("rx", axis_mapping, code_mapping, capabilities),
      y: axis_info("ry", axis_mapping, code_mapping, capabilities)
    }
  end

  defp axis_info(:dpad, axis_mapping, code_mapping, capabilities) do
    %{
      name: "D-Pad",
      key: "dpad",
      x: axis_info("dx", axis_mapping, code_mapping, capabilities),
      y: axis_info("dy", axis_mapping, code_mapping, capabilities)
    }
  end

  defp axis_info(name, axis_mapping, code_mapping, capabilities) do
    code = axis_mapping[name]

    case code_mapping[code] do
      {_type, _name, min, max, deadzone} ->
        %{
          label: text_label(name),
          key: String.to_atom(name),
          value: axis_mapping[name],
          options: axis_options(code_mapping, capabilities),
          code: code,
          min: min,
          max: max,
          deadzone: deadzone
        }

      _ ->
        %{
          label: text_label(name),
          key: String.to_atom(name),
          value: nil,
          options: axis_options(code_mapping, capabilities),
          code: code,
          min: 0,
          max: 0,
          deadzone: 0
        }
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
    Enum.reject(Proxy.list_devices(), &(&1["name"] == "vc4"))
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

  defp to_int(x) when x in ["", nil] do
    nil
  end

  defp to_int(string) when is_binary(string) do
    String.to_integer(string)
  end
end
