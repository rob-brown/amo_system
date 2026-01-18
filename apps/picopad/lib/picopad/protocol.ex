defmodule Picopad.Protocol do
  import Bitwise

  alias Picopad.COBS
  alias Picopad.CRC8

  @cmd_get_status 0x01
  @cmd_start_advertising 0x02
  @cmd_stop_advertising 0x03
  @cmd_disconnect 0x04
  @cmd_set_controller_type 0x05
  @cmd_set_buttons 0x10
  @cmd_set_all_buttons 0x11
  @cmd_clear_buttons 0x12
  @cmd_set_stick 0x13
  @cmd_set_stick_preset 0x14
  @cmd_get_input_state 0x15
  @cmd_press_button 0x20
  @cmd_amiibo_get_status 0x30
  @cmd_amiibo_load 0x31
  _ = @cmd_amiibo_load
  @cmd_amiibo_load_start 0x32
  @cmd_amiibo_load_chunk 0x33
  @cmd_amiibo_load_finish 0x34
  @cmd_amiibo_clear 0x37
  @cmd_amiibo_set_readonly 0x38
  @cmd_get_mcu_state 0x39
  @cmd_get_mcu_debug 0x3A
  @cmd_reconnect 0x40
  @cmd_forget_bonding 0x41
  @cmd_get_bonding_status 0x42
  @cmd_ping 0xF0
  @cmd_get_version 0xF1
  @cmd_reset 0xF2
  @cmd_set_led 0xF3
  @cmd_set_log_level 0xF4
  @evt_connection_changed 0xE0
  @evt_amiibo_scanned 0xE1
  @evt_amiibo_write_complete 0xE2
  @evt_error 0xE3
  @evt_log 0xE7

  @type_joycon_l 0x01
  @type_joycon_r 0x02
  @type_pro_controller 0x03

  @stick_left 0x00
  @stick_right 0x01

  @stick_preset_center 0x00
  @stick_preset_up 0x01
  @stick_preset_down 0x02
  @stick_preset_left 0x03
  @stick_preset_right 0x04
  @stick_preset_up_left 0x05
  @stick_preset_up_right 0x06
  @stick_preset_down_left 0x07
  @stick_preset_down_right 0x08

  @led_off 0x00
  @led_on 0x01
  @led_blink_slow 0x02
  @led_blink_fast 0x03
  @led_auto 0x04

  @log_none 0x00
  @log_emergency 0x01
  @log_alert 0x02
  @log_critical 0x03
  @log_error 0x04
  @log_warning 0x05
  @log_notice 0x06
  @log_info 0x07
  @log_debug 0x08

  @button_map %{
    y: {0, 0},
    x: {0, 1},
    b: {0, 2},
    a: {0, 3},
    r: {0, 6},
    zr: {0, 7},
    minus: {1, 0},
    plus: {1, 1},
    r_stick: {1, 2},
    l_stick: {1, 3},
    home: {1, 4},
    capture: {1, 5},
    down: {2, 0},
    up: {2, 1},
    right: {2, 2},
    left: {2, 3},
    l: {2, 6},
    zl: {2, 7}
  }

  def build_get_status, do: build_request(@cmd_get_status)
  def build_start_advertising, do: build_request(@cmd_start_advertising)
  def build_stop_advertising, do: build_request(@cmd_stop_advertising)
  def build_disconnect, do: build_request(@cmd_disconnect)
  def build_clear_buttons, do: build_request(@cmd_clear_buttons)
  def build_get_input_state, do: build_request(@cmd_get_input_state)
  def build_ping, do: build_request(@cmd_ping)
  def build_ping(data), do: build_request(@cmd_ping, data)
  def build_get_version, do: build_request(@cmd_get_version)
  def build_amiibo_get_status, do: build_request(@cmd_amiibo_get_status)
  def build_amiibo_load_finish, do: build_request(@cmd_amiibo_load_finish)
  def build_amiibo_clear, do: build_request(@cmd_amiibo_clear)
  def build_get_mcu_state, do: build_request(@cmd_get_mcu_state)
  def build_get_mcu_debug, do: build_request(@cmd_get_mcu_debug)
  def build_reconnect, do: build_request(@cmd_reconnect)
  def build_forget_bonding, do: build_request(@cmd_forget_bonding)
  def build_get_bonding_status, do: build_request(@cmd_get_bonding_status)

  def build_set_controller_type(type) do
    type_byte = controller_type_to_byte(type)
    build_request(@cmd_set_controller_type, <<type_byte>>)
  end

  def build_set_buttons(buttons, mask) when is_binary(buttons) and is_binary(mask) do
    build_request(@cmd_set_buttons, buttons <> mask)
  end

  def build_set_buttons(button_atoms) when is_list(button_atoms) do
    {buttons, mask} = buttons_to_bytes(button_atoms)
    build_set_buttons(buttons, mask)
  end

  def build_set_all_buttons(buttons) when is_binary(buttons) do
    build_request(@cmd_set_all_buttons, buttons)
  end

  def build_set_stick(stick, h, v) when is_integer(h) and is_integer(v) do
    stick_byte = stick_to_byte(stick)
    build_request(@cmd_set_stick, <<stick_byte, h::little-16, v::little-16>>)
  end

  def build_set_stick_preset(stick, preset) do
    stick_byte = stick_to_byte(stick)
    preset_byte = preset_to_byte(preset)
    build_request(@cmd_set_stick_preset, <<stick_byte, preset_byte>>)
  end

  def build_press_button(button, duration_ms \\ 0) do
    button_id = button_to_id(button)
    build_request(@cmd_press_button, <<button_id, duration_ms::little-16>>)
  end

  def build_amiibo_load_start(size) when is_integer(size) do
    build_request(@cmd_amiibo_load_start, <<size::little-16>>)
  end

  def build_amiibo_load_chunk(chunk_idx, data) when is_integer(chunk_idx) and is_binary(data) do
    build_request(@cmd_amiibo_load_chunk, <<chunk_idx>> <> data)
  end

  def build_amiibo_set_readonly(readonly) do
    byte = if readonly, do: 0x01, else: 0x00
    build_request(@cmd_amiibo_set_readonly, <<byte>>)
  end

  def build_reset(bootloader \\ false) do
    byte = if bootloader, do: 0x01, else: 0x00
    build_request(@cmd_reset, <<byte>>)
  end

  def build_set_led(mode) do
    mode_byte = led_mode_to_byte(mode)
    build_request(@cmd_set_led, <<mode_byte>>)
  end

  def build_set_log_level(level) do
    level_byte = log_level_to_byte(level)
    build_request(@cmd_set_log_level, <<level_byte>>)
  end

  def build_request(cmd, payload \\ <<>>) when is_integer(cmd) and is_binary(payload) do
    len = 2 + 1 + byte_size(payload) + 1
    packet = <<len::little-16, cmd>> <> payload
    crc = CRC8.calculate(packet)
    full_packet = packet <> <<crc>>
    COBS.encode(full_packet) <> <<0x00>>
  end

  def parse_response(data) when is_binary(data) do
    with {:ok, decoded} <- COBS.decode(data),
         {:ok, parsed} <- parse_decoded_response(decoded) do
      {:ok, parsed}
    end
  end

  defp parse_decoded_response(data) when byte_size(data) < 5 do
    {:error, :too_short}
  end

  defp parse_decoded_response(data) do
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

  def parse_event(data) when is_binary(data) do
    with {:ok, decoded} <- COBS.decode(data),
         {:ok, parsed} <- parse_decoded_event(decoded) do
      {:ok, parsed}
    end
  end

  defp parse_decoded_event(data) when byte_size(data) < 4 do
    {:error, :too_short}
  end

  defp parse_decoded_event(data) do
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

  def parse_status_payload(<<conn, type, player, amiibo, addr::binary-size(6)>>) do
    %{
      connection: connection_state_to_atom(conn),
      controller: controller_type_to_atom(type),
      player: if(player == 0xFF, do: nil, else: player),
      amiibo_loaded: amiibo == 0x01,
      switch_address: addr
    }
  end

  def parse_input_state_payload(
        <<buttons::binary-size(3), lh::little-16, lv::little-16, rh::little-16, rv::little-16>>
      ) do
    %{
      buttons: buttons,
      left_stick: {lh, lv},
      right_stick: {rh, rv}
    }
  end

  def parse_version_payload(<<major, minor, patch, version_string::binary>>) do
    %{
      major: major,
      minor: minor,
      patch: patch,
      version: String.trim_trailing(version_string, <<0>>)
    }
  end

  def parse_mcu_state_payload(
        <<mcu_state, nfc_state, input_mode, amiibo_loaded, last_report_id, last_mcu_cmd,
          last_mcu_subcmd, mcu_req_count::little-16>>
      ) do
    %{
      mcu_state: mcu_state_to_atom(mcu_state),
      nfc_state: nfc_state_to_atom(nfc_state),
      input_mode: input_mode_to_atom(input_mode),
      amiibo_loaded: amiibo_loaded == 1,
      last_report_id: last_report_id,
      last_mcu_cmd: last_mcu_cmd,
      last_mcu_subcmd: last_mcu_subcmd,
      mcu_request_count: mcu_req_count
    }
  end

  def parse_mcu_state_payload(<<mcu_state, nfc_state, input_mode, amiibo_loaded>>) do
    %{
      mcu_state: mcu_state_to_atom(mcu_state),
      nfc_state: nfc_state_to_atom(nfc_state),
      input_mode: input_mode_to_atom(input_mode),
      amiibo_loaded: amiibo_loaded == 1
    }
  end

  def parse_mcu_debug_payload(<<request::binary-size(16), response::binary-size(24)>>) do
    %{
      last_request: request,
      last_response: response
    }
  end

  def parse_bonding_status_payload(<<bonded, addr::binary-size(6), timestamp::32, count::16>>) do
    %{
      bonded: bonded == 1,
      switch_address: addr,
      last_connected_timestamp: timestamp,
      connection_count: count
    }
  end

  def parse_log_payload(<<level, message::binary>>) do
    %{
      level: log_level_to_atom(level),
      message: String.trim_trailing(message, <<0>>)
    }
  end

  def format_mcu_debug(%{last_request: req, last_response: resp}) do
    req_hex = Base.encode16(req, case: :lower)
    resp_hex = Base.encode16(resp, case: :lower)

    """
    Request:  #{req_hex}
    Response: #{resp_hex}
    """
  end

  defp mcu_state_to_atom(0x00), do: :suspended
  defp mcu_state_to_atom(0x01), do: :ready
  defp mcu_state_to_atom(0x04), do: :configured_nfc
  defp mcu_state_to_atom(val), do: {:unknown, val}

  defp nfc_state_to_atom(0x00), do: :none
  defp nfc_state_to_atom(0x01), do: :poll
  defp nfc_state_to_atom(0x02), do: :pending_read
  defp nfc_state_to_atom(0x03), do: :reading
  defp nfc_state_to_atom(0x09), do: :poll_again
  defp nfc_state_to_atom(val), do: {:unknown, val}

  defp input_mode_to_atom(0x21), do: :subcommand
  defp input_mode_to_atom(0x30), do: :imu
  defp input_mode_to_atom(0x31), do: :mcu
  defp input_mode_to_atom(0x3F), do: :simple
  defp input_mode_to_atom(val), do: {:unknown, val}

  def is_event?(cmd), do: cmd >= 0xE0 and cmd <= 0xEF

  defp status_to_atom(0x00), do: :ok
  defp status_to_atom(0x01), do: :unknown_command
  defp status_to_atom(0x02), do: :invalid_params
  defp status_to_atom(0x03), do: :busy
  defp status_to_atom(0x04), do: :not_connected
  defp status_to_atom(0x05), do: :amiibo_error
  defp status_to_atom(0xFF), do: :error
  defp status_to_atom(code), do: {:unknown, code}

  defp cmd_to_event(@evt_connection_changed), do: :connection_changed
  defp cmd_to_event(@evt_amiibo_scanned), do: :amiibo_scanned
  defp cmd_to_event(@evt_amiibo_write_complete), do: :amiibo_write_complete
  defp cmd_to_event(@evt_error), do: :error
  defp cmd_to_event(@evt_log), do: :log
  defp cmd_to_event(cmd), do: {:unknown, cmd}

  defp connection_state_to_atom(0x00), do: :disconnected
  defp connection_state_to_atom(0x01), do: :advertising
  defp connection_state_to_atom(0x02), do: :pairing
  defp connection_state_to_atom(0x03), do: :ready
  defp connection_state_to_atom(_), do: :unknown

  defp controller_type_to_atom(@type_joycon_l), do: :joycon_l
  defp controller_type_to_atom(@type_joycon_r), do: :joycon_r
  defp controller_type_to_atom(@type_pro_controller), do: :pro_controller
  defp controller_type_to_atom(_), do: :unknown

  defp controller_type_to_byte(:joycon_l), do: @type_joycon_l
  defp controller_type_to_byte(:joycon_r), do: @type_joycon_r
  defp controller_type_to_byte(:pro_controller), do: @type_pro_controller

  defp stick_to_byte(:left), do: @stick_left
  defp stick_to_byte(:right), do: @stick_right

  defp preset_to_byte(:center), do: @stick_preset_center
  defp preset_to_byte(:up), do: @stick_preset_up
  defp preset_to_byte(:down), do: @stick_preset_down
  defp preset_to_byte(:left), do: @stick_preset_left
  defp preset_to_byte(:right), do: @stick_preset_right
  defp preset_to_byte(:up_left), do: @stick_preset_up_left
  defp preset_to_byte(:up_right), do: @stick_preset_up_right
  defp preset_to_byte(:down_left), do: @stick_preset_down_left
  defp preset_to_byte(:down_right), do: @stick_preset_down_right

  defp led_mode_to_byte(:off), do: @led_off
  defp led_mode_to_byte(:on), do: @led_on
  defp led_mode_to_byte(:blink_slow), do: @led_blink_slow
  defp led_mode_to_byte(:blink_fast), do: @led_blink_fast
  defp led_mode_to_byte(:auto), do: @led_auto

  defp log_level_to_byte(:none), do: @log_none
  defp log_level_to_byte(:emergency), do: @log_emergency
  defp log_level_to_byte(:alert), do: @log_alert
  defp log_level_to_byte(:critical), do: @log_critical
  defp log_level_to_byte(:error), do: @log_error
  defp log_level_to_byte(:warning), do: @log_warning
  defp log_level_to_byte(:notice), do: @log_notice
  defp log_level_to_byte(:info), do: @log_info
  defp log_level_to_byte(:debug), do: @log_debug

  defp log_level_to_atom(@log_none), do: :none
  defp log_level_to_atom(@log_emergency), do: :emergency
  defp log_level_to_atom(@log_alert), do: :alert
  defp log_level_to_atom(@log_critical), do: :critical
  defp log_level_to_atom(@log_error), do: :error
  defp log_level_to_atom(@log_warning), do: :warning
  defp log_level_to_atom(@log_notice), do: :notice
  defp log_level_to_atom(@log_info), do: :info
  defp log_level_to_atom(@log_debug), do: :debug
  defp log_level_to_atom(level), do: {:unknown, level}

  defp button_to_id(:a), do: 0x00
  defp button_to_id(:b), do: 0x01
  defp button_to_id(:x), do: 0x02
  defp button_to_id(:y), do: 0x03
  defp button_to_id(:l), do: 0x04
  defp button_to_id(:r), do: 0x05
  defp button_to_id(:zl), do: 0x06
  defp button_to_id(:zr), do: 0x07
  defp button_to_id(:up), do: 0x08
  defp button_to_id(:down), do: 0x09
  defp button_to_id(:left), do: 0x0A
  defp button_to_id(:right), do: 0x0B
  defp button_to_id(:plus), do: 0x0C
  defp button_to_id(:minus), do: 0x0D
  defp button_to_id(:home), do: 0x0E
  defp button_to_id(:capture), do: 0x0F
  defp button_to_id(:l_stick), do: 0x10
  defp button_to_id(:r_stick), do: 0x11

  defp buttons_to_bytes(button_atoms) do
    {b0, b1, b2} =
      Enum.reduce(button_atoms, {0, 0, 0}, fn button, {b0, b1, b2} ->
        case Map.get(@button_map, button) do
          {0, bit} -> {b0 ||| 1 <<< bit, b1, b2}
          {1, bit} -> {b0, b1 ||| 1 <<< bit, b2}
          {2, bit} -> {b0, b1, b2 ||| 1 <<< bit}
          nil -> {b0, b1, b2}
        end
      end)

    {<<b0, b1, b2>>, <<b0, b1, b2>>}
  end
end
