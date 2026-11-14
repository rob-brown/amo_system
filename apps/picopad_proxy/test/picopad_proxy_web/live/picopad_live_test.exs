defmodule PicopadProxyWeb.PicopadLiveTest do
  use PicopadProxyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Picopad.Test.FakeUart
  alias PicopadProxy.ConnectionManager

  @dongle_info %{vendor_id: 12_259, product_id: 256}

  setup do
    ConnectionManager.disconnect()

    on_exit(fn ->
      ConnectionManager.disconnect()
      Application.delete_env(:picopad_proxy, :port_finder)
    end)

    :ok
  end

  defp install(kind, opts \\ []) do
    port = "fake-live-#{System.unique_integer([:positive])}"
    FakeUart.install(port, kind, opts)
    on_exit(fn -> FakeUart.uninstall(port) end)
    port
  end

  defp find_ports(ports) do
    Application.put_env(:picopad_proxy, :port_finder,
      ports: fn -> Map.new(ports, &{&1, @dongle_info}) end,
      probe_opts: [timeout: 50]
    )
  end

  describe "when nothing is connected" do
    test "offers to detect or connect and hides the Bluetooth controls", %{conn: conn} do
      # Arrange & Act
      {:ok, view, _html} = live(conn, "/picopad")

      # Assert
      assert has_element?(view, "#detect")
      assert has_element?(view, "#connect")
      refute has_element?(view, "#disconnect")
      refute has_element?(view, "#start-advertising")
      assert element(view, "#picopad-status") |> render() =~ "Disconnected"
      refute has_element?(view, "#picopad-firmware")
    end

    test "asks for a port before connecting", %{conn: conn} do
      # Arrange
      {:ok, view, _html} = live(conn, "/picopad")
      render_hook(view, "select_port", %{"port" => ""})

      # Act
      html = view |> element("#connect") |> render_click()

      # Assert
      assert html =~ "Please select a port first"
    end
  end

  describe "when the dongle is connected" do
    test "shows the firmware, the controller and an unknown player", %{conn: conn} do
      # Arrange
      port = install(:nordicpad, connection: 1)
      ConnectionManager.connect(port)

      # Act
      {:ok, view, _html} = live(conn, "/picopad")

      # Assert
      assert element(view, "#picopad-firmware") |> render() =~ "nRF52840 dongle (Switch 2)"
      assert element(view, "#picopad-firmware") |> render() =~ "Pro Controller"
      assert element(view, "#picopad-player") |> render() =~ "Unknown"
      assert element(view, "#picopad-status") |> render() =~ "Advertising"
      assert has_element?(view, "#disconnect")
      refute has_element?(view, "#detect")
    end

    test "stopping advertising switches the control and the status", %{conn: conn} do
      # Arrange
      port = install(:nordicpad, connection: 1)
      ConnectionManager.connect(port)
      {:ok, view, _html} = live(conn, "/picopad")

      # Act
      html = view |> element("#stop-advertising") |> render_click()

      # Assert
      assert html =~ "Stopped advertising"
      assert render(view) =~ "Connected, not advertising"
      assert has_element?(view, "#start-advertising")
      refute has_element?(view, "#stop-advertising")
    end

    test "shows a readable error when the firmware lacks a command", %{conn: conn} do
      # Arrange
      port = install(:nordicpad, radio: false, connection: 0)
      ConnectionManager.connect(port)
      {:ok, view, _html} = live(conn, "/picopad")

      # Act
      html = view |> element("#start-advertising") |> render_click()

      # Assert
      assert html =~ "Not supported by this firmware"
      refute html =~ "unknown_command"
      assert has_element?(view, "#start-advertising")
    end

    test "shows the Pico firmware", %{conn: conn} do
      # Arrange
      port = install(:picopad)
      ConnectionManager.connect(port)

      # Act
      {:ok, view, _html} = live(conn, "/picopad")

      # Assert
      assert element(view, "#picopad-firmware") |> render() =~ "Raspberry Pi Pico (Switch 1)"
    end

    test "disconnecting returns to the port controls", %{conn: conn} do
      # Arrange
      port = install(:nordicpad)
      ConnectionManager.connect(port)
      {:ok, view, _html} = live(conn, "/picopad")

      # Act
      view |> element("#disconnect") |> render_click()

      # Assert
      assert has_element?(view, "#connect")
      refute has_element?(view, "#picopad-firmware")
    end
  end

  describe "connecting to a chosen port" do
    test "reports a port another program holds", %{conn: conn} do
      # Arrange
      port = install(:busy)
      {:ok, view, _html} = live(conn, "/picopad")
      render_hook(view, "select_port", %{"port" => port})

      # Act
      html = view |> element("#connect") |> render_click()

      # Assert
      assert html =~ "Failed to connect: Port in use by another program"
      assert element(view, "#picopad-error") |> render() =~ "Port in use by another program"
    end
  end

  describe "detecting the device" do
    test "connects to the port that answers", %{conn: conn} do
      # Arrange
      log = install(:silent)
      host = install(:nordicpad)
      find_ports(Enum.sort([log, host]))
      {:ok, view, _html} = live(conn, "/picopad")

      # Act
      view |> element("#detect") |> render_click()
      html = render_async(view)

      # Assert
      assert html =~ "nRF52840 dongle (Switch 2)"
      assert ConnectionManager.status().port == host
      assert has_element?(view, "#disconnect")
    end

    test "says when nothing was found", %{conn: conn} do
      # Arrange
      find_ports([])
      {:ok, view, _html} = live(conn, "/picopad")

      # Act
      view |> element("#detect") |> render_click()
      html = render_async(view)

      # Assert
      assert html =~ "Detection failed: No Picopad or nordicpad found"
      assert has_element?(view, "#detect")
    end

    test "says when the port is in use", %{conn: conn} do
      # Arrange
      port = install(:busy)
      find_ports([port])
      {:ok, view, _html} = live(conn, "/picopad")

      # Act
      view |> element("#detect") |> render_click()
      html = render_async(view)

      # Assert
      assert html =~ "Port in use by another program: #{port}"
    end
  end
end
