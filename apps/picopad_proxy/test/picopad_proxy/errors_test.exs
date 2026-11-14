defmodule PicopadProxy.ErrorsTest do
  use ExUnit.Case, async: true

  alias PicopadProxy.ConnectionStatus
  alias PicopadProxy.Errors

  describe "normalize/1" do
    test "turns unknown_command into not_supported" do
      # Arrange
      result = {:error, :unknown_command}

      # Act
      normalized = Errors.normalize(result)

      # Assert
      assert normalized == {:error, :not_supported}
    end

    test "turns a held port into port_in_use" do
      # Arrange
      result = {:error, {:open_failed, :eagain}}

      # Act
      normalized = Errors.normalize(result)

      # Assert
      assert normalized == {:error, :port_in_use}
    end

    test "leaves other results alone" do
      # Arrange
      results = [:ok, {:ok, 1}, {:error, :busy}, {:error, {:open_failed, :enoent}}]

      # Act
      normalized = Enum.map(results, &Errors.normalize/1)

      # Assert
      assert normalized == results
    end
  end

  describe "message/1" do
    test "reads well for the errors the UI shows" do
      # Arrange
      reasons = [
        :not_supported,
        :port_in_use,
        {:port_in_use, ["/dev/a", "/dev/b"]},
        :not_found,
        :not_connected,
        :no_response,
        {:open_failed, :enoent}
      ]

      # Act
      messages = Enum.map(reasons, &Errors.message/1)

      # Assert
      assert messages == [
               "Not supported by this firmware",
               "Port in use by another program",
               "Port in use by another program: /dev/a, /dev/b",
               "No Picopad or nordicpad found",
               "Not connected",
               "The port did not answer the Picopad protocol",
               "Could not open the port (:enoent)"
             ]
    end

    test "falls back to inspect for anything else" do
      assert Errors.message({:weird, 1}) == "{:weird, 1}"
    end
  end

  describe "ConnectionStatus.from_firmware/1" do
    test "maps the firmware connection states to proxy statuses" do
      # Arrange
      states = [:disconnected, :advertising, :pairing, :ready, :unknown]

      # Act
      statuses = Enum.map(states, &ConnectionStatus.from_firmware/1)

      # Assert
      assert statuses == [:connected, :advertising, :pairing, :paired, :connected]
    end
  end
end
