defmodule Ssbu.MixProject do
  use Mix.Project

  def project do
    [
      app: :ssbu,
      version: "0.1.1",
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
      {:amiibo_serialization, path: "../amiibo_serialization"}
    ]
  end
end
