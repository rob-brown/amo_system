defmodule Autopilot.MixProject do
  use Mix.Project

  def project do
    [
      app: :autopilot,
      version: "0.3.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:vision, path: "../vision"},
      {:joycontrol, path: "../joycontrol", optional: true},
      {:luerl, "~> 1.5.1"}
    ]
  end
end
