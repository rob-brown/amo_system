defmodule SquadStrike.MixProject do
  use Mix.Project

  def project do
    [
      app: :squad_strike,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {SquadStrike.Application, []}
    ]
  end

  defp deps do
    [
      {:submission_info, path: "../submission_info"},
      {:challonge, path: "../challonge"},
      {:amqp, "~> 3.0"},
      {:jason, "~> 1.3"}
    ]
  end
end
