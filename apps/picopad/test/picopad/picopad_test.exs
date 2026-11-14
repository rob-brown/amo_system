defmodule Picopad.ApiTest do
  use ExUnit.Case, async: true

  alias Picopad.Test.FakeUart

  defp connect(kind, opts \\ []) do
    port = "fake-#{System.unique_integer([:positive])}"
    FakeUart.install(port, kind, opts)
    on_exit(fn -> FakeUart.uninstall(port) end)

    pid =
      start_supervised!(%{
        id: port,
        start: {Picopad, :connect, [port, [uart_module: FakeUart]]}
      })

    {port, pid}
  end

  defp dump(size) do
    for index <- 0..(size - 1), into: <<>>, do: <<rem(index * 7 + 3, 256)>>
  end

  describe "connect/2" do
    test "returns the open error and leaves the caller alive when the port cannot be opened" do
      # Arrange
      port = "fake-missing-#{System.unique_integer([:positive])}"
      caller = self()

      # Act
      result = Picopad.connect(port, uart_module: FakeUart)

      # Assert
      assert result == {:error, {:open_failed, :enoent}}
      refute_received {:EXIT, ^caller, _reason}
      assert Process.alive?(caller)
    end

    test "links the connection to the caller" do
      # Arrange
      port = "fake-#{System.unique_integer([:positive])}"
      FakeUart.install(port, :nordicpad)
      on_exit(fn -> FakeUart.uninstall(port) end)

      # Act
      {:ok, pid} = Picopad.connect(port, uart_module: FakeUart)
      {:links, links} = Process.info(self(), :links)

      # Assert
      assert pid in links
    end
  end

  describe "probe/2" do
    test "succeeds on a port that answers the protocol" do
      # Arrange
      port = "fake-#{System.unique_integer([:positive])}"
      FakeUart.install(port, :nordicpad)
      on_exit(fn -> FakeUart.uninstall(port) end)

      # Act
      result = Picopad.probe(port, uart_module: FakeUart)

      # Assert
      assert result == :ok
    end

    test "reports no_response for a port that stays silent" do
      # Arrange
      port = "fake-#{System.unique_integer([:positive])}"
      FakeUart.install(port, :silent)
      on_exit(fn -> FakeUart.uninstall(port) end)

      # Act
      result = Picopad.probe(port, uart_module: FakeUart, timeout: 50)

      # Assert
      assert result == {:error, :no_response}
    end

    test "reports the open error for a port that cannot be opened" do
      # Arrange
      port = "fake-missing-#{System.unique_integer([:positive])}"

      # Act
      result = Picopad.probe(port, uart_module: FakeUart)

      # Assert
      assert result == {:error, {:open_failed, :enoent}}
    end

    test "does not keep the port open" do
      # Arrange
      port = "fake-#{System.unique_integer([:positive])}"
      FakeUart.install(port, :nordicpad)
      on_exit(fn -> FakeUart.uninstall(port) end)
      uart_before = :persistent_term.get({FakeUart, :uart, port}, nil)

      # Act
      Picopad.probe(port, uart_module: FakeUart)
      uart = :persistent_term.get({FakeUart, :uart, port})
      ref = Process.monitor(uart)

      # Assert
      assert uart_before == nil
      assert_receive {:DOWN, ^ref, :process, ^uart, _reason}
    end
  end

  describe "commands the nordicpad firmware does not implement" do
    test "answer unknown_command instead of crashing or timing out" do
      # Arrange
      {_port, pid} = connect(:nordicpad)

      calls = [
        bonding_status: fn -> Picopad.bonding_status(pid) end,
        mcu_state: fn -> Picopad.mcu_state(pid) end,
        mcu_debug: fn -> Picopad.mcu_debug(pid) end,
        read_amiibo: fn -> Picopad.read_amiibo(pid) end,
        set_led: fn -> Picopad.set_led(pid, :on) end,
        set_log_level: fn -> Picopad.set_log_level(pid, :info) end,
        set_controller_type: fn -> Picopad.set_controller_type(pid, :pro_controller) end,
        amiibo_set_readonly: fn -> Picopad.amiibo_set_readonly(pid, true) end,
        bt_disconnect: fn -> Picopad.bt_disconnect(pid) end
      ]

      # Act
      results = for {name, call} <- calls, do: {name, call.()}

      # Assert
      for {name, result} <- results do
        assert {name, result} == {name, {:error, :unknown_command}}
      end
    end
  end

  describe "set_colors/2" do
    test "the Pico firmware answers unknown_command" do
      # Arrange
      {_port, pid} = connect(:picopad)

      # Act
      result =
        Picopad.set_colors(pid,
          body: {1, 2, 3},
          buttons: {4, 5, 6},
          highlight: {7, 8, 9},
          grip: {10, 11, 12}
        )

      # Assert
      assert result == {:error, :unknown_command}
    end

    test "sends body, buttons, highlight and grip as twelve bytes" do
      # Arrange
      {port, pid} = connect(:nordicpad)

      # Act
      result =
        Picopad.set_colors(pid,
          grip: {10, 11, 12},
          body: {1, 2, 3},
          highlight: {7, 8, 9},
          buttons: {4, 5, 6}
        )

      # Assert
      assert result == :ok
      assert {0x43, <<1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12>>} in FakeUart.received(port)
    end
  end

  describe "commands both firmwares implement" do
    for kind <- [:picopad, :nordicpad] do
      test "#{kind} accepts the advertising, reconnect and forget bonding commands" do
        # Arrange
        {_port, pid} = connect(unquote(kind))

        # Act
        results = [
          Picopad.start_advertising(pid),
          Picopad.stop_advertising(pid),
          Picopad.reconnect(pid),
          Picopad.forget_bonding(pid)
        ]

        # Assert
        assert results == [:ok, :ok, :ok, :ok]
      end

      test "#{kind} reports its status" do
        # Arrange
        {_port, pid} = connect(unquote(kind), connection: 2)

        # Act
        {:ok, status} = Picopad.status(pid)

        # Assert
        assert status.connection == :pairing
        assert status.controller == :pro_controller
        assert status.player == nil
        assert status.amiibo_loaded == false
      end
    end
  end

  describe "firmware/1" do
    test "recognises the Pico firmware" do
      # Arrange
      {_port, pid} = connect(:picopad)

      # Act
      result = Picopad.firmware(pid)

      # Assert
      assert result == {:ok, :picopad}
    end

    test "recognises the nordicpad firmware" do
      # Arrange
      {_port, pid} = connect(:nordicpad)

      # Act
      result = Picopad.firmware(pid)

      # Assert
      assert result == {:ok, :nordicpad}
    end
  end

  describe "buttons only the nordicpad Pro profile has" do
    test "hold sends the C, GL and GR bits in both the value and the mask" do
      # Arrange
      {port, pid} = connect(:nordicpad)

      # Act
      result = Picopad.hold(pid, [:c, :gl, :gr])

      # Assert
      assert result == :ok
      assert {0x10, <<0, 0xC0, 0x10, 0, 0xC0, 0x10>>} in FakeUart.received(port)
    end

    test "hold sends the SL and SR bits" do
      # Arrange
      {port, pid} = connect(:nordicpad)

      # Act
      result = Picopad.hold(pid, [:sl, :sr])

      # Assert
      assert result == :ok
      assert {0x10, <<0x30, 0, 0, 0x30, 0, 0>>} in FakeUart.received(port)
    end

    test "release clears only the mask for the requested buttons" do
      # Arrange
      {port, pid} = connect(:nordicpad)

      # Act
      result = Picopad.release(pid, [:gl])

      # Assert
      assert result == :ok
      assert {0x10, <<0, 0, 0, 0, 0x80, 0>>} in FakeUart.received(port)
    end

    test "press uses the button ids 0x14, 0x15 and 0x16" do
      # Arrange
      {port, pid} = connect(:nordicpad)

      # Act
      results = for button <- [:c, :gl, :gr], do: Picopad.press(pid, button, 100)

      # Assert
      assert results == [:ok, :ok, :ok]

      assert Enum.filter(FakeUart.received(port), &match?({0x20, _}, &1)) == [
               {0x20, <<0x14, 100::little-16>>},
               {0x20, <<0x15, 100::little-16>>},
               {0x20, <<0x16, 100::little-16>>}
             ]
    end
  end

  describe "amiibo transfer" do
    for size <- [540, 2048] do
      test "a #{size} byte dump loads and reads back unchanged" do
        # Arrange
        {_port, pid} = connect(:picopad)
        data = dump(unquote(size))

        # Act
        {:ok, %{uid: uid}} = Picopad.load_amiibo(pid, data)
        {:ok, status} = Picopad.amiibo_status(pid)
        read_back = Picopad.read_amiibo(pid)

        # Assert
        assert uid == binary_part(data, 0, 7)
        assert status == %{state: :loaded, uid: uid, size: unquote(size)}
        assert read_back == {:ok, data}
      end
    end

    test "a v3 dump loads on the nordicpad firmware" do
      # Arrange
      {_port, pid} = connect(:nordicpad)
      data = dump(2048)

      # Act
      result = Picopad.load_amiibo(pid, data)

      # Assert
      assert {:ok, %{uid: _uid}} = result
    end

    test "reading without a loaded amiibo reports amiibo_error" do
      # Arrange
      {_port, pid} = connect(:picopad)

      # Act
      result = Picopad.read_amiibo(pid)

      # Assert
      assert result == {:error, :amiibo_error}
    end

    test "clearing removes the loaded amiibo" do
      # Arrange
      {_port, pid} = connect(:nordicpad, amiibo: dump(540))

      # Act
      cleared = Picopad.clear_amiibo(pid)
      {:ok, status} = Picopad.amiibo_status(pid)

      # Assert
      assert cleared == :ok
      assert status.state == :none
    end
  end

  describe "events" do
    test "a 7 byte connection_changed event reaches the handler with its payload" do
      # Arrange
      {port, pid} = connect(:nordicpad)
      test_pid = self()
      Picopad.on_event(pid, :connection_changed, &send(test_pid, {:event, &1}))
      payload = <<3, 1, 2, 3, 4, 5, 6>>

      # Act
      FakeUart.emit(port, 0xE0, payload)

      # Assert
      assert_receive {:event, %{event: :connection_changed, payload: ^payload}}
    end

    for {cmd, name} <- [
          {0xE1, :amiibo_scanned},
          {0xE4, :reconnect_success},
          {0xE5, :reconnect_failed},
          {0xE6, :bonding_cleared}
        ] do
      test "event 0x#{Integer.to_string(cmd, 16)} is named #{name}" do
        # Arrange
        {port, pid} = connect(:nordicpad)
        test_pid = self()
        Picopad.on_event(pid, :all, &send(test_pid, {:event, &1}))

        # Act
        FakeUart.emit(port, unquote(cmd), <<0>>)

        # Assert
        assert_receive {:event, %{event: unquote(name), payload: <<0>>}}
      end
    end

    test "an event with an empty payload is delivered" do
      # Arrange
      {port, pid} = connect(:nordicpad)
      test_pid = self()
      Picopad.on_event(pid, :bonding_cleared, &send(test_pid, {:event, &1}))

      # Act
      FakeUart.emit(port, 0xE6, <<>>)

      # Assert
      assert_receive {:event, %{event: :bonding_cleared, payload: <<>>}}
    end
  end
end
