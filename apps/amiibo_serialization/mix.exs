defmodule AmiiboSerialization.MixProject do
  use Mix.Project

  def project do
    [
      app: :amiibo_serialization,
      version: "0.2.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto]
    ]
  end

  defp deps do
    []
  end
end
