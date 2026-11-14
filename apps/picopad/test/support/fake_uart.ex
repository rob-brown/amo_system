defmodule Picopad.Test.FakeUart do
  use GenServer

  alias Picopad.COBS
  alias Picopad.CRC8
  alias Picopad.Test.FakeFirmware

  def install(port, kind, opts \\ []) do
    :persistent_term.put({__MODULE__, :firmware, port}, FakeFirmware.new(kind, opts))
  end

  def uninstall(port) do
    :persistent_term.erase({__MODULE__, :firmware, port})
    :persistent_term.erase({__MODULE__, :uart, port})
  end

  def emit(port, event_cmd, payload) do
    GenServer.call(uart_for(port), {:emit, event_cmd, payload})
  end

  def received(port) do
    GenServer.call(uart_for(port), :received)
  end

  def start_link do
    GenServer.start_link(__MODULE__, nil)
  end

  def open(uart, port, _opts) do
    GenServer.call(uart, {:open, port, self()})
  end

  def write(uart, packet) do
    GenServer.call(uart, {:write, packet})
  end

  def close(_uart) do
    :ok
  end

  def stop(uart) do
    GenServer.stop(uart)
  end

  @impl true
  def init(nil) do
    {:ok, %{port: nil, owner: nil, firmware: nil, received: []}}
  end

  @impl true
  def handle_call({:open, port, owner}, _from, state) do
    case :persistent_term.get({__MODULE__, :firmware, port}, nil) do
      nil ->
        {:reply, {:error, :enoent}, state}

      firmware ->
        :persistent_term.put({__MODULE__, :uart, port}, self())
        {:reply, :ok, %{state | port: port, owner: owner, firmware: firmware}}
    end
  end

  def handle_call({:write, packet}, _from, state) do
    {cmd, payload} = decode_request(packet)
    {reply, firmware} = FakeFirmware.handle(state.firmware, cmd, payload)
    deliver_reply(state, cmd, reply)
    {:reply, :ok, %{state | firmware: firmware, received: state.received ++ [{cmd, payload}]}}
  end

  def handle_call({:emit, event_cmd, payload}, _from, state) do
    send(state.owner, {:circuits_uart, state.port, frame(<<event_cmd>>, payload)})
    {:reply, :ok, state}
  end

  def handle_call(:received, _from, state) do
    {:reply, state.received, state}
  end

  defp uart_for(port) do
    :persistent_term.get({__MODULE__, :uart, port})
  end

  defp decode_request(packet) do
    encoded = binary_part(packet, 0, byte_size(packet) - 1)
    {:ok, <<_len::little-16, cmd, rest::binary>>} = COBS.decode(encoded)
    {cmd, binary_part(rest, 0, byte_size(rest) - 1)}
  end

  defp deliver_reply(state, cmd, {:ok, payload}) do
    send(state.owner, {:circuits_uart, state.port, frame(<<cmd, 0x00>>, payload)})
  end

  defp deliver_reply(state, cmd, {:status, status}) do
    send(state.owner, {:circuits_uart, state.port, frame(<<cmd, status>>, <<>>)})
  end

  defp frame(header, payload) do
    length = 2 + byte_size(header) + byte_size(payload) + 1
    body = <<length::little-16>> <> header <> payload
    COBS.encode(body <> <<CRC8.calculate(body)>>) <> <<0x00>>
  end
end
