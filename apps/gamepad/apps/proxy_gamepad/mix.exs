defmodule ProxyGamepad.MixProject do
  use Mix.Project

  @version "VERSION" |> Path.expand(__DIR__) |> File.read!() |> String.trim()

  def project do
    [
      app: :proxy_gamepad,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:ui, path: "../ui"}
    ]
  end

  defp releases do
    [
      proxy: [
        steps: [:assemble, :tar],
        include_executables_for: [:unix],
        version: @version
      ]
    ]
  end
end
