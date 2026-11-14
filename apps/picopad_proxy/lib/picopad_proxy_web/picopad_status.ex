defmodule PicopadProxyWeb.PicopadStatus do
  def status_text(:disconnected), do: "Disconnected"
  def status_text(:connected), do: "Connected, not advertising"
  def status_text(:advertising), do: "Advertising"
  def status_text(:pairing), do: "Pairing"
  def status_text(:paired), do: "Paired (console connected)"

  def status_badge_class(:disconnected), do: "text-gray-500"
  def status_badge_class(:connected), do: "text-blue-600"
  def status_badge_class(:advertising), do: "text-yellow-600"
  def status_badge_class(:pairing), do: "text-orange-600"
  def status_badge_class(:paired), do: "text-green-600"

  def firmware_text(:picopad), do: "Raspberry Pi Pico (Switch 1)"
  def firmware_text(:nordicpad), do: "nRF52840 dongle (Switch 2)"
  def firmware_text(nil), do: nil

  def controller_text(:pro_controller), do: "Pro Controller"
  def controller_text(:joycon_l), do: "Joy-Con (L)"
  def controller_text(:joycon_r), do: "Joy-Con (R)"
  def controller_text(_controller), do: nil

  def player_text(nil), do: "Unknown"
  def player_text(player), do: "Player #{player}"
end
