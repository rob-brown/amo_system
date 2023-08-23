defmodule RabbitDriver.Application do
  @moduledoc false

  use Application

  @env Mix.env()

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: RabbitDriver.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  if @env == :test do
    defp children() do
      []
    end
  else
    defp children() do
      [
        Joycontrol,
        Vision,
        RabbitDriver.CommandQueue,
        RabbitDriver.ImageConsumer,
        RabbitDriver.ScriptConsumer
      ]
    end
  end
end
