defmodule Picopad do
  alias Picopad.Connection
  alias Picopad.Protocol

  require Logger

  @default_press_duration 50
  @default_probe_timeout 1_000

  def connect(port, opts \\ []) when is_binary(port) do
    opts = Keyword.put(opts, :port, port)
    Connection.start_link(opts)
  end

  def disconnect(pid) do
    Connection.close(pid)
  end

  @doc """
  Checks whether a serial port answers the host protocol, without keeping it open.

  The nordicpad dongle exposes two serial ports and only one speaks the protocol,
  so callers probe each candidate. Returns `:ok`, `{:error, :no_response}` when
  nothing answers within the timeout, or `{:error, {:open_failed, reason}}`, for
  example `:eagain` when another process holds the port.
  """
  def probe(port, opts \\ []) when is_binary(port) do
    {timeout, connect_opts} = Keyword.pop(opts, :timeout, @default_probe_timeout)

    with {:ok, pid} <- connect(port, connect_opts) do
      result = ping_within(pid, timeout)
      close_quietly(pid)
      result
    end
  end

  def status(pid) do
    with {:ok, payload} <- request(pid, Protocol.build_get_status()) do
      {:ok, Protocol.parse_status_payload(payload)}
    end
  end

  def start_advertising(pid) do
    send_simple_command(pid, Protocol.build_start_advertising())
  end

  def stop_advertising(pid) do
    send_simple_command(pid, Protocol.build_stop_advertising())
  end

  def bt_disconnect(pid) do
    send_simple_command(pid, Protocol.build_disconnect())
  end

  def reconnect(pid) do
    send_simple_command(pid, Protocol.build_reconnect())
  end

  def forget_bonding(pid) do
    send_simple_command(pid, Protocol.build_forget_bonding())
  end

  def bonding_status(pid) do
    with {:ok, payload} <- request(pid, Protocol.build_get_bonding_status()) do
      {:ok, Protocol.parse_bonding_status_payload(payload)}
    end
  end

  @doc """
  Sets the controller colors the console shows, effective on its next reconnect.
  Each part is an `{r, g, b}` tuple. Only the nordicpad firmware implements it;
  the Pico firmware answers `{:error, :unknown_command}`.
  """
  def set_colors(pid, colors) do
    send_simple_command(pid, Protocol.build_set_colors(colors))
  end

  def set_controller_type(pid, type) when type in [:joycon_l, :joycon_r, :pro_controller] do
    send_simple_command(pid, Protocol.build_set_controller_type(type))
  end

  def press(pid, button, duration_ms \\ @default_press_duration) do
    send_simple_command(pid, Protocol.build_press_button(button, duration_ms))
  end

  def hold(pid, buttons) when is_list(buttons) do
    send_simple_command(pid, Protocol.build_set_buttons(buttons))
  end

  def hold(pid, button) when is_atom(button) do
    hold(pid, [button])
  end

  def release(pid, buttons) when is_list(buttons) do
    {_pressed, mask} = Protocol.buttons_to_bytes(buttons)
    zeros = <<0, 0, 0>>
    send_simple_command(pid, Protocol.build_set_buttons(zeros, mask))
  end

  def release(pid, button) when is_atom(button) do
    release(pid, [button])
  end

  def release_all(pid) do
    send_simple_command(pid, Protocol.build_clear_buttons())
  end

  def stick(pid, which, preset)
      when preset in [
             :center,
             :up,
             :down,
             :left,
             :right,
             :up_left,
             :up_right,
             :down_left,
             :down_right
           ] do
    send_simple_command(pid, Protocol.build_set_stick_preset(which, preset))
  end

  def stick(pid, which, {h, v}) when is_integer(h) and is_integer(v) do
    send_simple_command(pid, Protocol.build_set_stick(which, h, v))
  end

  def input_state(pid) do
    with {:ok, payload} <- request(pid, Protocol.build_get_input_state()) do
      {:ok, Protocol.parse_input_state_payload(payload)}
    end
  end

  def ping(pid, data \\ <<>>) do
    packet = if data == <<>>, do: Protocol.build_ping(), else: Protocol.build_ping(data)
    request(pid, packet)
  end

  def version(pid) do
    with {:ok, payload} <- request(pid, Protocol.build_get_version()) do
      {:ok, Protocol.parse_version_payload(payload)}
    end
  end

  def firmware(pid) do
    with {:ok, %{version: version}} <- version(pid) do
      {:ok, Protocol.firmware_from_version(version)}
    end
  end

  def mcu_state(pid) do
    with {:ok, payload} <- request(pid, Protocol.build_get_mcu_state()) do
      {:ok, Protocol.parse_mcu_state_payload(payload)}
    end
  end

  def mcu_debug(pid) do
    with {:ok, payload} <- request(pid, Protocol.build_get_mcu_debug()) do
      {:ok, Protocol.parse_mcu_debug_payload(payload)}
    end
  end

  def print_mcu_debug(pid) do
    case mcu_debug(pid) do
      {:ok, debug} ->
        IO.puts(Protocol.format_mcu_debug(debug))
        :ok

      error ->
        error
    end
  end

  def reset(pid, bootloader \\ false) do
    packet = Protocol.build_reset(bootloader)
    Connection.send_command(pid, packet)
  end

  def set_led(pid, mode) when mode in [:off, :on, :blink_slow, :blink_fast, :auto] do
    send_simple_command(pid, Protocol.build_set_led(mode))
  end

  def set_log_level(pid, level)
      when level in [
             :none,
             :emergency,
             :alert,
             :critical,
             :error,
             :warning,
             :notice,
             :info,
             :debug
           ] do
    send_simple_command(pid, Protocol.build_set_log_level(level))
  end

  def amiibo_status(pid) do
    with {:ok, <<state, uid::binary-size(7), size::little-16>>} <-
           request(pid, Protocol.build_amiibo_get_status()) do
      {:ok,
       %{
         state: amiibo_state_to_atom(state),
         uid: uid,
         size: size
       }}
    end
  end

  def load_amiibo(pid, data, opts \\ []) when is_binary(data) do
    chunk_size = Keyword.get(opts, :chunk_size, 128)
    size = byte_size(data)

    with {:ok, <<pico_chunk_size>>} <- request(pid, Protocol.build_amiibo_load_start(size)) do
      actual_chunk_size = min(chunk_size, pico_chunk_size)
      chunks = chunk_binary(data, actual_chunk_size)

      result =
        Enum.reduce_while(Enum.with_index(chunks), :ok, fn {chunk, idx}, _acc ->
          case send_simple_command(pid, Protocol.build_amiibo_load_chunk(idx, chunk)) do
            :ok -> {:cont, :ok}
            error -> {:halt, error}
          end
        end)

      case result do
        :ok ->
          with {:ok, uid} <- request(pid, Protocol.build_amiibo_load_finish()) do
            {:ok, %{uid: uid}}
          end

        error ->
          error
      end
    end
  end

  def read_amiibo(pid) do
    with {:ok, payload} <- request(pid, Protocol.build_amiibo_read()) do
      %{size: size, chunk_size: chunk_size} = Protocol.parse_amiibo_read_payload(payload)
      num_chunks = div(size + chunk_size - 1, chunk_size)

      chunks =
        Enum.reduce_while(0..(num_chunks - 1)//1, [], fn idx, acc ->
          case request(pid, Protocol.build_amiibo_read_chunk(idx)) do
            {:ok, chunk_data} -> {:cont, [chunk_data | acc]}
            error -> {:halt, error}
          end
        end)

      case chunks do
        {:error, _} = error ->
          error

        chunk_list when is_list(chunk_list) ->
          data = chunk_list |> Enum.reverse() |> IO.iodata_to_binary()
          {:ok, data}
      end
    end
  end

  def clear_amiibo(pid) do
    send_simple_command(pid, Protocol.build_amiibo_clear())
  end

  def amiibo_set_readonly(pid, readonly \\ true) do
    send_simple_command(pid, Protocol.build_amiibo_set_readonly(readonly))
  end

  @doc """
  Command provided to match interface to `joycontrol` app.
  Intended to be called by `autopilot` app.
  Though currently no scripts use this function.
  """
  def command(_string) do
    Logger.error("Arbitrary commands not implemented")
  end

  def on_event(pid, event, handler) when is_function(handler) do
    Connection.register_event_handler(pid, event, handler)
  end

  def off_event(pid, event) do
    Connection.unregister_event_handler(pid, event)
  end

  def log_to_logger(pid) do
    on_log(pid, fn %{level: level, message: message} ->
      Logger.bare_log(level, message)
    end)
  end

  def log_to_file(pid, path, level) do
    set_log_level(pid, level)

    log_to_file(pid, path)
  end

  def log_to_file(pid, path) do
    on_log(pid, fn %{level: level, message: message} ->
      msg = ["[", to_string(level), "] ", message, "\n"]
      File.write(path, msg, [:append])
    end)

    :ok
  end

  def on_log(pid, handler) when is_function(handler) do
    wrapped_handler = fn %{event: :log, payload: payload} ->
      parsed = Protocol.parse_log_payload(payload)
      handler.(parsed)
    end

    Connection.register_event_handler(pid, :log, wrapped_handler)
  end

  defp ping_within(pid, timeout) do
    case Connection.send_command(pid, Protocol.build_ping(), timeout) do
      {:ok, %{status: :ok}} -> :ok
      {:ok, %{status: status}} -> {:error, status}
      error -> error
    end
  catch
    :exit, {:timeout, _call} -> {:error, :no_response}
    :exit, reason -> {:error, {:exit, reason}}
  end

  defp close_quietly(pid) do
    Connection.close(pid)
  catch
    :exit, _reason -> :ok
  end

  defp request(pid, packet) do
    case Connection.send_command(pid, packet) do
      {:ok, %{status: :ok, payload: payload}} -> {:ok, payload}
      {:ok, %{status: status}} -> {:error, status}
      error -> error
    end
  end

  defp send_simple_command(pid, packet) do
    with {:ok, _payload} <- request(pid, packet) do
      :ok
    end
  end

  defp chunk_binary(binary, chunk_size) do
    chunk_binary(binary, chunk_size, [])
  end

  defp chunk_binary(<<>>, _chunk_size, acc), do: Enum.reverse(acc)

  defp chunk_binary(binary, chunk_size, acc) when byte_size(binary) <= chunk_size do
    Enum.reverse([binary | acc])
  end

  defp chunk_binary(binary, chunk_size, acc) do
    <<chunk::binary-size(chunk_size), rest::binary>> = binary
    chunk_binary(rest, chunk_size, [chunk | acc])
  end

  defp amiibo_state_to_atom(0x00), do: :none
  defp amiibo_state_to_atom(0x01), do: :loaded
  defp amiibo_state_to_atom(0x02), do: :reading
  defp amiibo_state_to_atom(0x03), do: :writing
  defp amiibo_state_to_atom(_), do: :unknown
end
