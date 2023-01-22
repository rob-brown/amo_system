defmodule TournamentRunner.MixProject do
  use Mix.Project

  def project do
    [
      app: :tournament_runner,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {TournamentRunner.Application, []}
    ]
  end

  defp deps do
    [
      {:autopilot, path: "../autopilot"},
      {:challonge, path: "../challonge"},
      {:submission_info, path: "../submission_info"}
    ]
  end
end
