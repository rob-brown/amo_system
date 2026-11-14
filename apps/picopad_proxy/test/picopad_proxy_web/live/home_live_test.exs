defmodule PicopadProxyWeb.HomeLiveTest do
  use PicopadProxyWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Picopad.Test.FakeUart
  alias PicopadProxy.ConnectionManager

  setup do
    ConnectionManager.disconnect()
    on_exit(fn -> ConnectionManager.disconnect() end)
    :ok
  end

  defp install(kind, opts \\ []) do
    port = "fake-home-#{System.unique_integer([:positive])}"
    FakeUart.install(port, kind, opts)
    on_exit(fn -> FakeUart.uninstall(port) end)
    port
  end

  test "shows the page with the Picopad disconnected", %{conn: conn} do
    # Arrange & Act
    {:ok, view, html} = live(conn, "/")

    # Assert
    assert html =~ "Picopad Proxy"
    assert element(view, "#home-picopad-status") |> render() =~ "Disconnected"
    refute has_element?(view, "#home-picopad-firmware")
  end

  test "shows the dongle with a stored console connected", %{conn: conn} do
    # Arrange
    port = install(:nordicpad, connection: 3)
    ConnectionManager.connect(port)

    # Act
    {:ok, view, _html} = live(conn, "/")

    # Assert
    assert element(view, "#home-picopad-status") |> render() =~ "Paired (console connected)"
    assert element(view, "#home-picopad-firmware") |> render() =~ "nRF52840 dongle (Switch 2)"
    assert element(view, "#home-picopad-player") |> render() =~ "Unknown"
  end

  test "shows the Pico", %{conn: conn} do
    # Arrange
    port = install(:picopad, connection: 1)
    ConnectionManager.connect(port)

    # Act
    {:ok, view, _html} = live(conn, "/")

    # Assert
    assert element(view, "#home-picopad-status") |> render() =~ "Advertising"
    assert element(view, "#home-picopad-firmware") |> render() =~ "Raspberry Pi Pico (Switch 1)"
  end

  test "shows the last connection error", %{conn: conn} do
    # Arrange
    port = install(:busy)
    ConnectionManager.connect(port)

    # Act
    {:ok, view, _html} = live(conn, "/")

    # Assert
    assert element(view, "#home-picopad-error") |> render() =~ "Port in use by another program"
  end
end
