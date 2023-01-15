defmodule Autopilot.MixProject do
  use Mix.Project

  def project do
    [
      app: :autopilot,
      version: "0.1.0",
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
      {:joycontrol, path: "../joycontrol"},
      {:sandbox, "~> 0.5.0"}
    ]
  end
end
