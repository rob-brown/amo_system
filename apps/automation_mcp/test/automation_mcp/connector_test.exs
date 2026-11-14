defmodule AutomationMCP.ConnectorTest do
  use ExUnit.Case, async: true

  alias AutomationMCP.Connector
  alias AutomationMCP.Connector.State

  describe "handle_info/2 for connection_changed events" do
    test "maps a real 7 byte event to the connection status" do
      # Arrange
      state = %State{status: :connected, player_number: 2}
      payload = <<3, 0, 0, 0, 0, 0, 0>>

      # Act
      {:noreply, new_state} =
        Connector.handle_info({:picopad_event, :connection_changed, payload}, state)

      # Assert
      assert new_state.status == :paired
      assert new_state.player_number == 2
    end

    test "maps each connection state" do
      # Arrange
      state = %State{status: :connected}
      expected = [{0, :connected}, {1, :advertising}, {2, :pairing}, {3, :paired}]

      # Act
      statuses =
        for {byte, _status} <- expected do
          payload = <<byte, 0, 0, 0, 0, 0, 0>>

          {:noreply, new_state} =
            Connector.handle_info({:picopad_event, :connection_changed, payload}, state)

          new_state.status
        end

      # Assert
      assert statuses == for({_byte, status} <- expected, do: status)
    end

    test "keeps the current state when the payload has an unknown layout" do
      # Arrange
      state = %State{status: :paired}

      # Act
      result = Connector.handle_info({:picopad_event, :connection_changed, <<3, 0>>}, state)

      # Assert
      assert result == {:noreply, state}
    end
  end
end
