defmodule PicopadProxy.PortFinderTest do
  use ExUnit.Case, async: true

  alias PicopadProxy.PortFinder

  @dongle %{vendor_id: 12_259, product_id: 256}
  @pico %{vendor_id: 11_914}

  defp probe_with(answers) do
    test_pid = self()

    fn port, _opts ->
      send(test_pid, {:probed, port})
      Map.fetch!(answers, port)
    end
  end

  defp probed_ports(acc \\ []) do
    receive do
      {:probed, port} -> probed_ports([port | acc])
    after
      0 -> Enum.reverse(acc)
    end
  end

  describe "find/1" do
    test "picks the dongle port that answers and skips the log port" do
      # Arrange
      ports = %{"/dev/cu.usbmodem5101" => @dongle, "/dev/cu.usbmodem5103" => @dongle}

      probe =
        probe_with(%{
          "/dev/cu.usbmodem5101" => {:error, :no_response},
          "/dev/cu.usbmodem5103" => :ok
        })

      # Act
      result = PortFinder.find(ports: fn -> ports end, probe: probe)

      # Assert
      assert result == {:ok, "/dev/cu.usbmodem5103"}
      assert probed_ports() == ["/dev/cu.usbmodem5101", "/dev/cu.usbmodem5103"]
    end

    test "stops probing at the first port that answers" do
      # Arrange
      ports = %{"/dev/a" => @pico, "/dev/b" => @dongle}
      probe = probe_with(%{"/dev/a" => :ok, "/dev/b" => :ok})

      # Act
      result = PortFinder.find(ports: fn -> ports end, probe: probe)

      # Assert
      assert result == {:ok, "/dev/a"}
      assert probed_ports() == ["/dev/a"]
    end

    test "ignores ports from other vendors" do
      # Arrange
      ports = %{
        "/dev/cu.Bluetooth-Incoming-Port" => %{},
        "/dev/cu.other" => %{vendor_id: 1},
        "/dev/cu.usbmodem1" => @pico
      }

      probe = probe_with(%{"/dev/cu.usbmodem1" => :ok})

      # Act
      result = PortFinder.find(ports: fn -> ports end, probe: probe)

      # Assert
      assert result == {:ok, "/dev/cu.usbmodem1"}
      assert probed_ports() == ["/dev/cu.usbmodem1"]
    end

    test "reports not_found when no candidate answers" do
      # Arrange
      ports = %{"/dev/a" => @dongle, "/dev/b" => @dongle}

      probe =
        probe_with(%{
          "/dev/a" => {:error, :no_response},
          "/dev/b" => {:error, {:open_failed, :enoent}}
        })

      # Act
      result = PortFinder.find(ports: fn -> ports end, probe: probe)

      # Assert
      assert result == {:error, :not_found}
    end

    test "reports not_found when there are no ports" do
      # Arrange
      ports = %{}

      # Act
      result = PortFinder.find(ports: fn -> ports end, probe: probe_with(%{}))

      # Assert
      assert result == {:error, :not_found}
    end

    test "reports the ports another program holds" do
      # Arrange
      ports = %{"/dev/a" => @dongle, "/dev/b" => @dongle}

      probe =
        probe_with(%{
          "/dev/a" => {:error, {:open_failed, :eagain}},
          "/dev/b" => {:error, {:open_failed, :eagain}}
        })

      # Act
      result = PortFinder.find(ports: fn -> ports end, probe: probe)

      # Assert
      assert result == {:error, {:port_in_use, ["/dev/a", "/dev/b"]}}
    end

    test "prefers a port that answers over one that is in use" do
      # Arrange
      ports = %{"/dev/a" => @dongle, "/dev/b" => @dongle}
      probe = probe_with(%{"/dev/a" => {:error, {:open_failed, :eagain}}, "/dev/b" => :ok})

      # Act
      result = PortFinder.find(ports: fn -> ports end, probe: probe)

      # Assert
      assert result == {:ok, "/dev/b"}
    end

    test "hands the probe options to every probe" do
      # Arrange
      test_pid = self()
      ports = %{"/dev/a" => @dongle}

      probe = fn port, opts ->
        send(test_pid, {:opts, port, opts})
        :ok
      end

      # Act
      PortFinder.find(ports: fn -> ports end, probe: probe, probe_opts: [timeout: 25])

      # Assert
      assert_received {:opts, "/dev/a", [timeout: 25]}
    end
  end
end
