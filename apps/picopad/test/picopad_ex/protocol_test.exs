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
