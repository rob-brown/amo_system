defmodule RabbitDriver.MixProject do
  use Mix.Project

  @version "0.1.0"

  def project do
    [
      app: :rabbit_driver,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {RabbitDriver.Application, []}
    ]
  end

  defp releases() do
    [
      rabbit_driver: [
        steps: [:assemble, :tar],
        include_executables_for: [:unix],
        version: @version
      ]
    ]
  end

  defp deps do
    [
      {:autopilot, path: "../autopilot"},
      {:amqp, "~> 3.0"},
      {:jason, "~> 1.3"}
    ]
  end
end
