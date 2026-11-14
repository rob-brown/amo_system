defmodule AutomationMCP.MixProject do
  use Mix.Project

  def project do
    [
      app: :automation_mcp,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AutomationMCP.Application, []}
    ]
  end

  defp releases do
    [
      automation_mcp: [
        include_executables_for: [:unix]
      ]
    ]
  end

  defp deps do
    [
      {:anubis_mcp, "~> 1.14"},
      {:autopilot, path: "../autopilot"},
      {:bandit, "~> 1.5"},
      {:picopad, path: "../picopad"},
      {:plug, "~> 1.16"},
      {:vision, path: "../vision"}
    ]
  end
end
