defmodule Picopad.ProtocolTest do
  use ExUnit.Case

  alias Picopad.Protocol

  describe "build_request/1" do
    test "builds ping request" do
      # Arrange & Act
      packet = Protocol.build_ping()

      # Assert
      assert is_binary(packet)
      assert byte_size(packet) > 0
      assert :binary.last(packet) == 0x00
    end

    test "builds get_status request" do
      # Arrange & Act
      packet = Protocol.build_get_status()

      # Assert
      assert is_binary(packet)
      assert :binary.last(packet) == 0x00
    end
  end

  describe "build_set_stick_preset/2" do
    test "builds left stick up" do
      # Arrange & Act
      packet = Protocol.build_set_stick_preset(:left, :up)

      # Assert
      assert is_binary(packet)
    end

    test "builds right stick center" do
      # Arrange & Act
      packet = Protocol.build_set_stick_preset(:right, :center)

      # Assert
      assert is_binary(packet)
    end
  end

  describe "build_press_button/2" do
    test "builds press A button" do
      # Arrange & Act
      packet = Protocol.build_press_button(:a, 100)

      # Assert
      assert is_binary(packet)
    end
  end

  describe "parse_status_payload/1" do
    test "parses status payload" do
      # Arrange
      payload = <<0x03, 0x03, 0x01, 0x00, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>

      # Act
      result = Protocol.parse_status_payload(payload)

      # Assert
      assert result.connection == :ready
      assert result.controller == :pro_controller
      assert result.player == 1
      assert result.amiibo_loaded == false
      assert result.switch_address == <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
    end

    test "parses disconnected status" do
      # Arrange
      payload = <<0x00, 0x03, 0xFF, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00>>

      # Act
      result = Protocol.parse_status_payload(payload)

      # Assert
      assert result.connection == :disconnected
      assert result.player == nil
    end
  end

  describe "parse_version_payload/1" do
    test "parses version payload" do
      # Arrange
      payload = <<1, 0, 0, "1.0.0", 0>>

      # Act
      result = Protocol.parse_version_payload(payload)

      # Assert
      assert result.major == 1
      assert result.minor == 0
      assert result.patch == 0
      assert result.version == "1.0.0"
    end
  end

  describe "request byte layouts" do
    defp decode_request(packet) do
      encoded = binary_part(packet, 0, byte_size(packet) - 1)
      {:ok, <<len::little-16, cmd, rest::binary>>} = Picopad.COBS.decode(encoded)
      payload = binary_part(rest, 0, byte_size(rest) - 1)
      crc = :binary.last(rest)
      body = binary_part(<<len::little-16, cmd, rest::binary>>, 0, len - 1)
      assert len == byte_size(payload) + 4
      assert crc == Picopad.CRC8.calculate(body)
      {cmd, payload}
    end

    test "every builder produces the command id and payload the firmware expects" do
      # Arrange
      expected = [
        {Protocol.build_get_status(), 0x01, <<>>},
        {Protocol.build_start_advertising(), 0x02, <<>>},
        {Protocol.build_stop_advertising(), 0x03, <<>>},
        {Protocol.build_disconnect(), 0x04, <<>>},
        {Protocol.build_set_controller_type(:pro_controller), 0x05, <<3>>},
        {Protocol.build_set_buttons(<<1, 2, 3>>, <<4, 5, 6>>), 0x10, <<1, 2, 3, 4, 5, 6>>},
        {Protocol.build_set_all_buttons(<<1, 2, 3>>), 0x11, <<1, 2, 3>>},
        {Protocol.build_clear_buttons(), 0x12, <<>>},
        {Protocol.build_set_stick(:right, 0x0234, 0x0178), 0x13, <<1, 0x34, 0x02, 0x78, 0x01>>},
        {Protocol.build_set_stick_preset(:left, :down_right), 0x14, <<0, 8>>},
        {Protocol.build_get_input_state(), 0x15, <<>>},
        {Protocol.build_press_button(:a, 0x0164), 0x20, <<0, 0x64, 0x01>>},
        {Protocol.build_amiibo_get_status(), 0x30, <<>>},
        {Protocol.build_amiibo_load_start(2048), 0x32, <<0x00, 0x08>>},
        {Protocol.build_amiibo_load_chunk(3, <<9, 8>>), 0x33, <<3, 9, 8>>},
        {Protocol.build_amiibo_load_finish(), 0x34, <<>>},
        {Protocol.build_amiibo_read(), 0x35, <<>>},
        {Protocol.build_amiibo_read_chunk(15), 0x36, <<15>>},
        {Protocol.build_amiibo_clear(), 0x37, <<>>},
        {Protocol.build_amiibo_set_readonly(true), 0x38, <<1>>},
        {Protocol.build_get_mcu_state(), 0x39, <<>>},
        {Protocol.build_get_mcu_debug(), 0x3A, <<>>},
        {Protocol.build_reconnect(), 0x40, <<>>},
        {Protocol.build_forget_bonding(), 0x41, <<>>},
        {Protocol.build_get_bonding_status(), 0x42, <<>>},
        {Protocol.build_set_colors(
           body: {1, 2, 3},
           buttons: {4, 5, 6},
           highlight: {7, 8, 9},
           grip: {10, 11, 12}
         ), 0x43, <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12>>},
        {Protocol.build_ping(), 0xF0, <<>>},
        {Protocol.build_ping(<<1, 2>>), 0xF0, <<1, 2>>},
        {Protocol.build_get_version(), 0xF1, <<>>},
        {Protocol.build_reset(true), 0xF2, <<1>>},
        {Protocol.build_set_led(:blink_fast), 0xF3, <<3>>},
        {Protocol.build_set_log_level(:debug), 0xF4, <<8>>}
      ]

      # Act
      decoded = for {packet, _cmd, _payload} <- expected, do: decode_request(packet)

      # Assert
      assert decoded == for({_packet, cmd, payload} <- expected, do: {cmd, payload})
    end

    test "press button ids for the nordicpad only buttons" do
      # Arrange
      ids = [sl: 0x12, sr: 0x13, c: 0x14, gl: 0x15, gr: 0x16]

      # Act
      decoded =
        for {button, _id} <- ids, do: decode_request(Protocol.build_press_button(button, 0))

      # Assert
      assert decoded == for({_button, id} <- ids, do: {0x20, <<id, 0, 0>>})
    end
  end

  describe "buttons_to_bytes/1" do
    test "maps the nordicpad only buttons to their bits" do
      # Arrange
      buttons = [:sl, :sr, :c, :gl, :gr]

      # Act
      {pressed, mask} = Protocol.buttons_to_bytes(buttons)

      # Assert
      assert pressed == <<0x30, 0xC0, 0x10>>
      assert mask == pressed
    end

    test "ignores buttons it does not know" do
      # Arrange
      buttons = [:a, :turbo]

      # Act
      {pressed, _mask} = Protocol.buttons_to_bytes(buttons)

      # Assert
      assert pressed == <<0x08, 0, 0>>
    end
  end

  describe "parse_connection_changed_payload/1" do
    test "parses the 7 byte event both firmwares send" do
      # Arrange
      payload = <<3, 0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>

      # Act
      result = Protocol.parse_connection_changed_payload(payload)

      # Assert
      assert result == %{
               connection: :ready,
               switch_address: <<0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF>>
             }
    end

    test "maps every connection state" do
      # Arrange
      states = [{0, :disconnected}, {1, :advertising}, {2, :pairing}, {3, :ready}]

      # Act
      parsed =
        for {byte, _atom} <- states do
          Protocol.parse_connection_changed_payload(<<byte, 0, 0, 0, 0, 0, 0>>).connection
        end

      # Assert
      assert parsed == for({_byte, atom} <- states, do: atom)
    end

    test "rejects the 10 byte get_status layout" do
      # Arrange
      payload = <<3, 3, 0xFF, 0, 0, 0, 0, 0, 0, 0>>

      # Act
      result = Protocol.parse_connection_changed_payload(payload)

      # Assert
      assert result == :error
    end

    test "get_status parsing rejects the 7 byte event layout" do
      # Arrange
      payload = <<3, 0, 0, 0, 0, 0, 0>>

      # Act
      result = Protocol.parse_status_payload(payload)

      # Assert
      assert result == :error
    end
  end

  describe "parse_bonding_status_payload/1" do
    test "parses the 13 byte layout" do
      # Arrange
      payload = <<1, 1, 2, 3, 4, 5, 6, 0, 0, 0x01, 0x02, 0, 7>>

      # Act
      result = Protocol.parse_bonding_status_payload(payload)

      # Assert
      assert result == %{
               bonded: true,
               switch_address: <<1, 2, 3, 4, 5, 6>>,
               last_connected_timestamp: 0x0102,
               connection_count: 7
             }
    end
  end

  describe "parse_decoded_event/1" do
    defp event_body(cmd, payload) do
      body = <<byte_size(payload) + 4::little-16, cmd>> <> payload
      body <> <<Picopad.CRC8.calculate(body)>>
    end

    test "names every event the firmwares send" do
      # Arrange
      events = [
        {0xE0, :connection_changed},
        {0xE1, :amiibo_scanned},
        {0xE2, :amiibo_write_complete},
        {0xE3, :error},
        {0xE4, :reconnect_success},
        {0xE5, :reconnect_failed},
        {0xE6, :bonding_cleared},
        {0xE7, :log},
        {0xE8, {:unknown, 0xE8}}
      ]

      # Act
      parsed =
        for {cmd, _name} <- events do
          {:ok, %{event: event}} = Protocol.parse_decoded_event(event_body(cmd, <<>>))
          event
        end

      # Assert
      assert parsed == for({_cmd, name} <- events, do: name)
    end

    test "rejects a corrupted checksum" do
      # Arrange
      body = event_body(0xE6, <<>>)
      corrupted = binary_part(body, 0, byte_size(body) - 1) <> <<0>>

      # Act
      result = Protocol.parse_decoded_event(corrupted)

      # Assert
      assert result == {:error, :crc_mismatch}
    end
  end

  describe "parse_decoded_response/1" do
    test "maps every status byte" do
      # Arrange
      statuses = [
        {0x00, :ok},
        {0x01, :unknown_command},
        {0x02, :invalid_params},
        {0x03, :busy},
        {0x04, :not_connected},
        {0x05, :amiibo_error},
        {0xFF, :error},
        {0x42, {:unknown, 0x42}}
      ]

      # Act
      parsed =
        for {byte, _atom} <- statuses do
          body = <<5::little-16, 0x40, byte>>

          {:ok, %{status: status}} =
            Protocol.parse_decoded_response(body <> <<Picopad.CRC8.calculate(body)>>)

          status
        end

      # Assert
      assert parsed == for({_byte, atom} <- statuses, do: atom)
    end
  end

  describe "firmware_from_version/1" do
    test "a nordicpad version string is the nordicpad firmware" do
      assert Protocol.firmware_from_version("nordicpad 0.1.0") == :nordicpad
    end

    test "the Pico version string is the picopad firmware" do
      assert Protocol.firmware_from_version("1.0.0") == :picopad
    end

    test "an empty version string is the picopad firmware" do
      assert Protocol.firmware_from_version("") == :picopad
    end
  end

  describe "is_event?/1" do
    test "connection_changed is an event" do
      assert Protocol.is_event?(0xE0)
    end

    test "ping is not an event" do
      refute Protocol.is_event?(0xF0)
    end

    test "get_status is not an event" do
      refute Protocol.is_event?(0x01)
    end
  end
end
