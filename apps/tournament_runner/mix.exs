defmodule TournamentRunner.MixProject do
  use Mix.Project

  @version "1.0.0"

  def project do
    [
      app: :tournament_runner,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: releases()
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

  defp releases() do
    [
      tournament_runner: [
        steps: [:assemble, :tar],
        include_executables_for: [:unix],
        version: @version
      ]
    ]
  end
end
