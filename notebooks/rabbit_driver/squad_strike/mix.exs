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
      {:challonge, github: "rob-brown/amo_system", subdir: "apps/challonge"},
      {:submission_info, github: "rob-brown/amo_system", subdir: "apps/submission_info"},
      {:amqp, "~> 3.0"},
      {:jason, "~> 1.3"}
    ]
  end
end
