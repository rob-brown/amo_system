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
      {:autopilot, path: Path.expand("../../apps/autopilot", __DIR__)},
      {:challonge, path: Path.expand("../../apps/challonge", __DIR__)},
      {:submission_info, path: Path.expand("../../apps/submission_info", __DIR__)},
      {:picopad, path: Path.expand("../../apps/picopad", __DIR__)},
      # {:autopilot, github: "rob-brown/amo_system", subdir: "apps/autopilot"},
      # {:challonge, github: "rob-brown/amo_system", subdir: "apps/challonge"},
      # {:submission_info, github: "rob-brown/amo_system", subdir: "apps/submission_info"},
      {:jason, "~> 1.4"}
    ]
  end
end
