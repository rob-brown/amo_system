defmodule PicopadProxyWeb.PicopadStatusTest do
  use ExUnit.Case, async: true

  alias PicopadProxyWeb.PicopadStatus

  describe "status_text/1" do
    test "describes every status the manager reports" do
      # Arrange
      statuses = [:disconnected, :connected, :advertising, :pairing, :paired]

      # Act
      texts = Enum.map(statuses, &PicopadStatus.status_text/1)

      # Assert
      assert texts == [
               "Disconnected",
               "Connected, not advertising",
               "Advertising",
               "Pairing",
               "Paired (console connected)"
             ]
    end
  end

  describe "firmware_text/1" do
    test "names the console generation each firmware talks to" do
      assert PicopadStatus.firmware_text(:picopad) == "Raspberry Pi Pico (Switch 1)"
      assert PicopadStatus.firmware_text(:nordicpad) == "nRF52840 dongle (Switch 2)"
      assert PicopadStatus.firmware_text(nil) == nil
    end
  end

  describe "controller_text/1" do
    test "names the controller types" do
      assert PicopadStatus.controller_text(:pro_controller) == "Pro Controller"
      assert PicopadStatus.controller_text(:joycon_l) == "Joy-Con (L)"
      assert PicopadStatus.controller_text(:joycon_r) == "Joy-Con (R)"
      assert PicopadStatus.controller_text(:unknown) == nil
    end
  end

  describe "player_text/1" do
    test "says Unknown when the firmware reports no player" do
      assert PicopadStatus.player_text(nil) == "Unknown"
    end

    test "names the player slot" do
      assert PicopadStatus.player_text(2) == "Player 2"
    end
  end
end
