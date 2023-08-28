defmodule RabbitDriver.Application do
  @moduledoc false

  use Application

  @env Mix.env()
  @target Mix.target()

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
      case @target do
        :host ->
          [
            RabbitDriver.CommandQueue,
            RabbitDriver.ImageConsumer,
            RabbitDriver.ScriptConsumer
          ]

        :rpi ->
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
end
