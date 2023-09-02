defmodule RabbitDriver.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: RabbitDriver.Supervisor]
    Supervisor.start_link(children(), opts)
  end

  case {Mix.env(), Mix.target()} do
    {:test, _} ->
      defp children() do
        []
      end

    {:dev, :host} ->
      defp children() do
        :host ->
          [
            RabbitDriver.ImageConsumer,
            RabbitDriver.ScriptConsumer
          ]
      end

    _ ->
      defp children() do
        [
          Joycontrol,
          Vision,
          RabbitDriver.ImageConsumer,
          RabbitDriver.ScriptConsumer
        ]
      end
  end
end
