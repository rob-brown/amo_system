defmodule Picopad.Connection do
  use GenServer

  alias Picopad.COBS
  alias Picopad.CRC8
  alias Picopad.Protocol

  @default_baud 115_200
  @response_timeout 5_000

  defstruct [
    :uart,
    :port,
    :timeout_timer,
    rx_buffer: <<>>,
    pending_request: nil,
    event_handlers: %{}
  ]

  def start_link(opts) do
    port = Keyword.fetch!(opts, :port)
    name = Keyword.get(opts, :name)
    baud = Keyword.get(opts, :baud, @default_baud)

    gen_opts = if name, do: [name: name], else: []
    GenServer.start_link(__MODULE__, %{port: port, baud: baud}, gen_opts)
  end

  def send_command(pid, packet, timeout \\ @response_timeout) do
    GenServer.call(pid, {:send_command, packet}, timeout)
  end

  def register_event_handler(pid, event, handler) when is_function(handler) do
    GenServer.call(pid, {:register_handler, event, handler})
  end

  def unregister_event_handler(pid, event) do
    GenServer.call(pid, {:unregister_handler, event})
  end

  def close(pid) do
    GenServer.stop(pid, :normal)
  end

  @impl true
  def init(%{port: port, baud: baud}) do
    case Circuits.UART.start_link() do
      {:ok, uart} ->
        uart_opts = [
          speed: baud,
          data_bits: 8,
          stop_bits: 1,
          parity: :none,
          active: true
        ]

        case Circuits.UART.open(uart, port, uart_opts) do
          :ok ->
            state = %__MODULE__{uart: uart, port: port}
            {:ok, state}

          {:error, reason} ->
            Circuits.UART.stop(uart)
            {:stop, {:open_failed, reason}}
        end

      {:error, reason} ->
        {:stop, {:uart_start_failed, reason}}
    end
  end

  @impl true
  def handle_call({:send_command, packet}, from, state) do
    case state.pending_request do
      nil ->
        if state.timeout_timer, do: Process.cancel_timer(state.timeout_timer)

        Circuits.UART.write(state.uart, packet)
        timer = Process.send_after(self(), :command_timeout, @response_timeout + 100)

        new_state = %{state | pending_request: from, timeout_timer: timer}
        {:noreply, new_state}

      _existing ->
        {:reply, {:error, :busy}, state}
    end
  end

  def handle_call({:register_handler, event, handler}, _from, state) do
    new_handlers = Map.put(state.event_handlers, event, handler)
    {:reply, :ok, %{state | event_handlers: new_handlers}}
  end

  def handle_call({:unregister_handler, event}, _from, state) do
    new_handlers = Map.delete(state.event_handlers, event)
    {:reply, :ok, %{state | event_handlers: new_handlers}}
  end

  @impl true
  def handle_info(:command_timeout, state) do
    IO.puts("Command timeout - clearing pending request state")

    if state.timeout_timer, do: Process.cancel_timer(state.timeout_timer)

    new_state = %{state | pending_request: nil, timeout_timer: nil, rx_buffer: <<>>}
    {:noreply, new_state}
  end

  def handle_info({:circuits_uart, _port, {:error, reason}}, state) do
    if state.timeout_timer, do: Process.cancel_timer(state.timeout_timer)

    if state.pending_request do
      GenServer.reply(state.pending_request, {:error, {:uart_error, reason}})
    end

    {:stop, {:uart_error, reason}, %{state | pending_request: nil, timeout_timer: nil}}
  end

  def handle_info({:circuits_uart, _port, data}, state) when is_binary(data) do
    new_buffer = state.rx_buffer <> data
    new_state = process_buffer(%{state | rx_buffer: new_buffer})
    {:noreply, new_state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.timeout_timer, do: Process.cancel_timer(state.timeout_timer)

    if state.uart do
      Circuits.UART.close(state.uart)
      Circuits.UART.stop(state.uart)
    end

    :ok
  end

  defp process_buffer(state) do
    case find_frame(state.rx_buffer) do
      {:ok, frame, rest} ->
        new_state = handle_frame(frame, %{state | rx_buffer: rest})
        process_buffer(new_state)

      :incomplete ->
        state
    end
  end

  defp find_frame(buffer) do
    case :binary.match(buffer, <<0x00>>) do
      {pos, 1} ->
        <<frame::binary-size(pos), 0x00, rest::binary>> = buffer
        {:ok, frame, rest}

      :nomatch ->
        :incomplete
    end
  end

  defp handle_frame(frame, state) when byte_size(frame) == 0, do: state

  defp handle_frame(frame, state) do
    case COBS.decode(frame) do
      {:ok, decoded} when byte_size(decoded) >= 4 ->
        handle_decoded_packet(decoded, state)

      _ ->
        state
    end
  end

  defp handle_decoded_packet(decoded, state) do
    <<_len::little-16, cmd, _rest::binary>> = decoded

    if Protocol.is_event?(cmd) do
      handle_event(decoded, state)
    else
      handle_response(decoded, state)
    end
  end

  defp handle_response(decoded, state) do
    case state.pending_request do
      nil ->
        state

      from ->
        if state.timeout_timer, do: Process.cancel_timer(state.timeout_timer)

        result = parse_response_packet(decoded)
        GenServer.reply(from, result)
        %{state | pending_request: nil, timeout_timer: nil}
    end
  end

  defp parse_response_packet(data) when byte_size(data) < 5 do
    {:error, :too_short}
  end

  defp parse_response_packet(data) do
    <<len::little-16, cmd, status, rest::binary>> = data
    payload_size = byte_size(rest) - 1
    <<payload::binary-size(payload_size), crc>> = rest

    expected_crc = CRC8.calculate(binary_part(data, 0, byte_size(data) - 1))

    cond do
      len != byte_size(data) -> {:error, :length_mismatch}
      crc != expected_crc -> {:error, :crc_mismatch}
      true -> {:ok, %{cmd: cmd, status: status_to_atom(status), payload: payload}}
    end
  end

  defp handle_event(decoded, state) do
    case parse_event_packet(decoded) do
      {:ok, %{event: event} = parsed} ->
        case Map.get(state.event_handlers, event) do
          nil -> :ok
          handler -> spawn(fn -> handler.(parsed) end)
        end

        case Map.get(state.event_handlers, :all) do
          nil -> :ok
          handler -> spawn(fn -> handler.(parsed) end)
        end

      _ ->
        :ok
    end

    state
  end

  defp parse_event_packet(data) when byte_size(data) < 4 do
    {:error, :too_short}
  end

  defp parse_event_packet(data) do
    <<len::little-16, cmd, rest::binary>> = data
    payload_size = byte_size(rest) - 1
    <<payload::binary-size(payload_size), crc>> = rest

    expected_crc = CRC8.calculate(binary_part(data, 0, byte_size(data) - 1))

    cond do
      len != byte_size(data) -> {:error, :length_mismatch}
      crc != expected_crc -> {:error, :crc_mismatch}
      true -> {:ok, %{event: cmd_to_event(cmd), payload: payload}}
    end
  end

  defp status_to_atom(0x00), do: :ok
  defp status_to_atom(0x01), do: :unknown_command
  defp status_to_atom(0x02), do: :invalid_params
  defp status_to_atom(0x03), do: :busy
  defp status_to_atom(0x04), do: :not_connected
  defp status_to_atom(0x05), do: :amiibo_error
  defp status_to_atom(0xFF), do: :error
  defp status_to_atom(code), do: {:unknown, code}

  defp cmd_to_event(0xE0), do: :connection_changed
  defp cmd_to_event(0xE1), do: :amiibo_scanned
  defp cmd_to_event(0xE2), do: :amiibo_write_complete
  defp cmd_to_event(0xE3), do: :error
  defp cmd_to_event(0xE7), do: :log
  defp cmd_to_event(cmd), do: {:unknown, cmd}
end
