defmodule Gamepad.Application do
  @moduledoc false

  use Application

  require Logger

  @impl true
  def start(_type, _args) do
    children = [
      Gamepad.Bluetooth.Notifier,
      Gamepad.InputTracker,
      {DynamicSupervisor, strategy: :one_for_one, name: Gamepad.DynamicSupervisor}
    ]

    opts = [strategy: :one_for_one, name: Gamepad.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
