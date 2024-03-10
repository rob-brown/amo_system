defmodule Gamepad.MixProject do
  use Mix.Project

  def project do
    [
      app: :gamepad,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {Gamepad.Application, []}
    ]
  end

  defp deps do
    [
      {:joycontrol, path: "../../../joycontrol"}
    ]
  end
end
