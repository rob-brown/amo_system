defmodule PicopadProxy.ConnectionStatus do
  def from_firmware(:disconnected), do: :connected
  def from_firmware(:advertising), do: :advertising
  def from_firmware(:pairing), do: :pairing
  def from_firmware(:ready), do: :paired
  def from_firmware(_state), do: :connected
end
