defmodule Vision.MixProject do
  use Mix.Project

  def project do
    [
      app: :vision,
      version: "0.3.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:evision, "~> 0.1.33"}
    ]
  end
end
