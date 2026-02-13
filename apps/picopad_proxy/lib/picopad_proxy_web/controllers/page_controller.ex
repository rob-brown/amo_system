defmodule PicopadProxyWeb.PageController do
  use PicopadProxyWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
