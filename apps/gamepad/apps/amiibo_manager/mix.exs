defmodule AmiiboManager.MixProject do
  use Mix.Project

  def project do
    [
      app: :amiibo_manager,
      version: "0.1.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {AmiiboManager.Application, []}
    ]
  end

  defp deps do
    [
      {:ecto_sqlite3, "~> 0.7.7"},
      {:ssbu, path: "../../../ssbu"},
      {:slugify, "~> 1.3"}
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "setup"]
    ]
  end
end
