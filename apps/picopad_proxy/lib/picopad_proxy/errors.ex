defmodule PicopadProxy.Errors do
  def normalize({:error, :unknown_command}), do: {:error, :not_supported}
  def normalize({:error, {:open_failed, :eagain}}), do: {:error, :port_in_use}
  def normalize(result), do: result

  def message(:not_supported), do: "Not supported by this firmware"
  def message(:port_in_use), do: "Port in use by another program"

  def message({:port_in_use, ports}) do
    "Port in use by another program: #{Enum.join(ports, ", ")}"
  end

  def message(:not_found), do: "No Picopad or nordicpad found"
  def message(:not_connected), do: "Not connected"
  def message(:amiibo_error), do: "The firmware rejected the amiibo"
  def message(:busy), do: "The firmware is busy, try again"
  def message(:no_response), do: "The port did not answer the Picopad protocol"
  def message({:open_failed, reason}), do: "Could not open the port (#{inspect(reason)})"
  def message(reason), do: inspect(reason)
end
