defmodule PicopadProxy.MixProject do
  use Mix.Project

  def project do
    [
      app: :picopad_proxy,
      version: "0.2.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader]
    ]
  end

  def application do
    [
      mod: {PicopadProxy.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  defp elixirc_paths(:test) do
    ["lib", "test/support", Path.expand("../picopad/test/support", __DIR__)]
  end

  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # Phoenix deps
      {:phoenix, "~> 1.8.3"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:phoenix_live_dashboard, "~> 0.8.3"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.3", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:bandit, "~> 1.5"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:telemetry_metrics, "~> 1.0"},

      # Application deps
      {:amiibo_manager, path: "../gamepad/apps/amiibo_manager"},
      {:amiibo_serialization, path: "../amiibo_serialization"},
      {:gilrs_ex, path: "../gilrs_ex"},
      {:picopad, path: "../picopad"},
      {:ssbu, path: "../ssbu"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "assets.setup", "assets.build"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind picopad_proxy", "esbuild picopad_proxy"],
      "assets.deploy": [
        "tailwind picopad_proxy --minify",
        "esbuild picopad_proxy --minify",
        "phx.digest"
      ],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
