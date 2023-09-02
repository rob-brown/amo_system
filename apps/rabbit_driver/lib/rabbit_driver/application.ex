defmodule RabbitDriver.Application do
  @moduledoc false

  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: RabbitDriver.Supervisor]
    target = Application.get_env(:rabbit_driver, :target)

    Supervisor.start_link(children(@env, target), opts)
  end

  defp children(:test, _target) do
    []
  end

  defp children(_env, :host) do
    [
      RabbitDriver.ImageConsumer,
      RabbitDriver.ScriptConsumer
    ]
  end

  defp children(_env, _target) do
    [
      Joycontrol,
      Vision,
      RabbitDriver.ImageConsumer,
      RabbitDriver.ScriptConsumer
    ]
  end
end
