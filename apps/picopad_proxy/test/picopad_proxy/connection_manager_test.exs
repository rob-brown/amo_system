defmodule PicopadProxy.ConnectionManagerTest do
  use ExUnit.Case, async: false

  alias Picopad.Test.FakeUart
  alias PicopadProxy.ConnectionManager

  @dongle_info %{vendor_id: 12_259, product_id: 256}

  setup do
    ConnectionManager.disconnect()
    Phoenix.PubSub.subscribe(PicopadProxy.PubSub, "picopad:connection")
    Phoenix.PubSub.subscribe(PicopadProxy.PubSub, "picopad:events")

    on_exit(fn ->
      ConnectionManager.disconnect()
      Application.delete_env(:picopad_proxy, :port_finder)
      Application.delete_env(:picopad, :response_timeout)
    end)

    :ok
  end

  defp install(kind, opts \\ [], label \\ "port") do
    port = "fake-#{label}-#{System.unique_integer([:positive])}"
    FakeUart.install(port, kind, opts)
    on_exit(fn -> FakeUart.uninstall(port) end)
    port
  end

  defp dump(size) do
    for index <- 0..(size - 1), into: <<>>, do: <<rem(index * 5 + 1, 256)>>
  end

  describe "connect/1" do
    test "records the nordicpad firmware, the status and an unknown player" do
      # Arrange
      port = install(:nordicpad)

      # Act
      result = ConnectionManager.connect(port)
      status = ConnectionManager.status()

      # Assert
      assert result == :ok
      assert status.status == :paired
      assert status.firmware == :nordicpad
      assert status.port == port
      assert status.player_number == nil
      assert status.last_error == nil
    end

    test "records the Pico firmware" do
      # Arrange
      port = install(:picopad)

      # Act
      ConnectionManager.connect(port)

      # Assert
      assert ConnectionManager.status().firmware == :picopad
    end

    test "broadcasts the connection with the firmware" do
      # Arrange
      port = install(:nordicpad, connection: 1)

      # Act
      ConnectionManager.connect(port)

      # Assert
      assert_receive {:connection_changed,
                      %{status: :advertising, firmware: :nordicpad, port: ^port}}
    end

    test "replaces an existing connection" do
      # Arrange
      first = install(:nordicpad)
      second = install(:picopad)
      ConnectionManager.connect(first)

      # Act
      result = ConnectionManager.connect(second)
      status = ConnectionManager.status()

      # Assert
      assert result == :ok
      assert status.port == second
      assert status.firmware == :picopad
    end

    test "reports a port another program holds as port_in_use" do
      # Arrange
      port = install(:busy)

      # Act
      result = ConnectionManager.connect(port)
      status = ConnectionManager.status()

      # Assert
      assert result == {:error, :port_in_use}
      assert status.status == :disconnected
      assert status.last_error == "Port in use by another program"
      assert_receive {:error, "Port in use by another program"}
    end

    test "reports a missing port without crashing" do
      # Arrange
      manager = Process.whereis(ConnectionManager)

      # Act
      result = ConnectionManager.connect("fake-missing-#{System.unique_integer([:positive])}")

      # Assert
      assert result == {:error, {:open_failed, :enoent}}
      assert Process.whereis(ConnectionManager) == manager
      assert ConnectionManager.status().status == :disconnected
    end

    test "reports a port that never answers as no_response without crashing" do
      # Arrange
      Application.put_env(:picopad, :response_timeout, 100)
      port = install(:silent)
      manager = Process.whereis(ConnectionManager)

      # Act
      result = ConnectionManager.connect(port)
      status = ConnectionManager.status()

      # Assert
      assert result == {:error, :no_response}
      assert Process.whereis(ConnectionManager) == manager
      assert status.status == :disconnected
      assert status.last_error == "The port did not answer the Picopad protocol"
    end
  end

  describe "auto_connect/0" do
    defp find_ports(ports, probe_opts \\ [timeout: 50]) do
      Application.put_env(:picopad_proxy, :port_finder,
        ports: fn -> Map.new(ports, &{&1, @dongle_info}) end,
        probe_opts: probe_opts
      )
    end

    test "skips the dongle log port and connects to the host port" do
      # Arrange
      log = install(:silent, [], "a-log")
      host = install(:nordicpad, [], "b-host")
      find_ports([log, host])

      # Act
      result = ConnectionManager.auto_connect()
      status = ConnectionManager.status()

      # Assert
      assert result == :ok
      assert status.port == host
      assert status.firmware == :nordicpad
    end

    test "reports not_found when nothing answers" do
      # Arrange
      find_ports([])

      # Act
      result = ConnectionManager.auto_connect()

      # Assert
      assert result == {:error, :not_found}
      assert ConnectionManager.status().last_error == "No Picopad or nordicpad found"
    end

    test "reports the ports that are in use" do
      # Arrange
      port = install(:busy)
      find_ports([port])

      # Act
      result = ConnectionManager.auto_connect()

      # Assert
      assert result == {:error, {:port_in_use, [port]}}
      assert ConnectionManager.status().last_error == "Port in use by another program: #{port}"
    end

    test "keeps an existing connection" do
      # Arrange
      port = install(:nordicpad)
      ConnectionManager.connect(port)
      find_ports([])

      # Act
      result = ConnectionManager.auto_connect()

      # Assert
      assert result == :ok
      assert ConnectionManager.status().port == port
    end
  end

  describe "radio commands" do
    test "start and stop advertising follow what the firmware reports" do
      # Arrange
      port = install(:nordicpad, connection: 0)
      ConnectionManager.connect(port)
      assert ConnectionManager.status().status == :connected

      # Act
      started = ConnectionManager.start_advertising()
      advertising = ConnectionManager.status().status
      stopped = ConnectionManager.stop_advertising()
      quiet = ConnectionManager.status().status

      # Assert
      assert {started, advertising, stopped, quiet} == {:ok, :advertising, :ok, :connected}
    end

    test "stopping while paired does not claim the link dropped" do
      # Arrange
      port = install(:nordicpad, connection: 3)
      ConnectionManager.connect(port)

      # Act
      result = ConnectionManager.stop_advertising()

      # Assert
      assert result == :ok
      assert ConnectionManager.status().status == :paired
    end

    test "reconnect and forget bonding are sent to the firmware" do
      # Arrange
      port = install(:nordicpad)
      ConnectionManager.connect(port)

      # Act
      results = [ConnectionManager.reconnect(), ConnectionManager.forget_bonding()]

      # Assert
      assert results == [:ok, :ok]

      radio_commands =
        Enum.filter(FakeUart.received(port), fn {cmd, _payload} -> cmd in [0x40, 0x41] end)

      assert radio_commands == [{0x40, <<>>}, {0x41, <<>>}]
    end

    test "a firmware without the commands answers not_supported and keeps its status" do
      # Arrange
      port = install(:nordicpad, radio: false, connection: 0)
      ConnectionManager.connect(port)
      assert_receive {:connection_changed, %{status: :connected}}

      # Act
      results = [
        ConnectionManager.start_advertising(),
        ConnectionManager.stop_advertising(),
        ConnectionManager.reconnect(),
        ConnectionManager.forget_bonding()
      ]

      # Assert
      assert results == List.duplicate({:error, :not_supported}, 4)
      assert ConnectionManager.status().status == :connected
      refute_receive {:connection_changed, _info}, 100
    end

    test "answer not_connected without a connection" do
      # Arrange
      commands = [
        &ConnectionManager.start_advertising/0,
        &ConnectionManager.stop_advertising/0,
        &ConnectionManager.reconnect/0,
        &ConnectionManager.forget_bonding/0,
        &ConnectionManager.clear_amiibo/0
      ]

      # Act
      results = Enum.map(commands, & &1.())

      # Assert
      assert results == List.duplicate({:error, :not_connected}, 5)
    end
  end

  describe "events" do
    test "a 7 byte connection_changed event updates and broadcasts the status" do
      # Arrange
      port = install(:nordicpad, connection: 0)
      ConnectionManager.connect(port)
      assert_receive {:connection_changed, %{status: :connected}}

      # Act
      FakeUart.emit(port, 0xE0, <<2, 0, 0, 0, 0, 0, 0>>)

      # Assert
      assert_receive {:connection_changed, %{status: :pairing, firmware: :nordicpad}}
      assert ConnectionManager.status().status == :pairing
    end

    test "a malformed connection_changed payload keeps the status" do
      # Arrange
      port = install(:nordicpad, connection: 3)
      ConnectionManager.connect(port)

      # Act
      FakeUart.emit(port, 0xE0, <<2, 0>>)
      status = ConnectionManager.status()

      # Assert
      assert status.status == :paired
    end

    test "amiibo scanned is broadcast" do
      # Arrange
      port = install(:nordicpad)
      ConnectionManager.connect(port)

      # Act
      FakeUart.emit(port, 0xE1, <<0>>)

      # Assert
      assert_receive {:picopad_event, {:amiibo_scanned, <<0>>}}
    end

    for {cmd, event} <- [
          {0xE4, :reconnect_success},
          {0xE5, :reconnect_failed},
          {0xE6, :bonding_cleared}
        ] do
      test "#{event} is broadcast" do
        # Arrange
        port = install(:nordicpad)
        ConnectionManager.connect(port)

        # Act
        FakeUart.emit(port, unquote(cmd), <<>>)

        # Assert
        assert_receive {:picopad_event, unquote(event)}
      end
    end
  end

  describe "amiibo" do
    test "loads a 2048 byte v3 dump and clears it" do
      # Arrange
      port = install(:nordicpad)
      ConnectionManager.connect(port)

      # Act
      loaded = ConnectionManager.load_amiibo(dump(2048))
      cleared = ConnectionManager.clear_amiibo()

      # Assert
      assert loaded == :ok
      assert cleared == :ok
      assert_receive {:picopad_event, {:amiibo_loaded, %{uid: _uid}}}
      assert_receive {:picopad_event, :amiibo_cleared}
    end

    test "loading without a connection answers not_connected" do
      # Arrange
      data = dump(540)

      # Act
      result = ConnectionManager.load_amiibo(data)

      # Assert
      assert result == {:error, :not_connected}
    end
  end
end
