defmodule Bracket.MixProject do
  use Mix.Project

  def project do
    [
      app: :bracket,
      version: "0.1.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      escript: escript(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp escript do
    [main_module: Bracket.CLI]
  end

  defp deps do
    [
      {:toml, "~> 0.7"}
    ]
  end
end
