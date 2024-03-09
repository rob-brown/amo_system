defmodule Proxy.MixProject do
  use Mix.Project

  @version "VERSION" |> File.read!() |> String.trim()

  def project do
    [
      app: :proxy,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Proxy.Application, []}
    ]
  end

  defp deps do
    [
      {:ui, path: "../ui"},
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
