defmodule AutomationMCP.MixProject do
  use Mix.Project

  def project do
    [
      app: :automation_mcp,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AutomationMCP.Application, []}
    ]
  end

  defp deps do
    [
      {:anubis_mcp, "~> 1.14"},
      {:autopilot, path: "../autopilot"},
      {:picopad, path: "../picopad"},
      {:vision, path: "../vision"}
    ]
  end
end
