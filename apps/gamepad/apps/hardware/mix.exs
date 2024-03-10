defmodule Hardware.MixProject do
  use Mix.Project

  @version "VERSION" |> Path.expand(__DIR__) |> File.read!() |> String.trim()

  def project do
    [
      app: :hardware,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      mod: {Hardware.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:gamepad, path: "../gamepad"},
      {:ui, path: "../ui"},
      {:circuits_gpio, "~> 1.0"},
      {:circuits_i2c, "~> 1.1"},
      {:pigpiox, "~> 0.1.2"}
    ]
  end

  defp releases do
    [
      gamepad: [
        steps: [:assemble, :tar],
        include_executables_for: [:unix],
        version: @version
      ]
    ]
  end
end
