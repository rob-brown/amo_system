defmodule Ui.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      UiWeb.Telemetry,
      {Phoenix.PubSub, name: Ui.PubSub},
      UiWeb.Endpoint,
      Joycontrol,
      # joycontrol()
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Ui.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    UiWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp joycontrol() do
    case Gamepad.Bluetooth.paired_devices() do
      {:ok, [_ | _]} ->
        {Gamepad.Joycontrol, reconnect: true}

      _ ->
        {Gamepad.Joycontrol, []}
    end
  end
end
