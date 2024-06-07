# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configures the endpoint
config :ui, UiWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [view: UiWeb.ErrorView, accepts: ~w(html json), layout: false],
  pubsub_server: Ui.PubSub,
  live_view: [signing_salt: "hN+4zJu0"]

config :amiibo_manager,
  ecto_repos: [AmiiboManager.Repo]

config :amiibo_manager, AmiiboManager.Repo,
  adapter: Ecto.Adapters.SQLite3,
  database: "amiibo.sqlite"

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.12.18",
  default: [
    args:
      ~w(js/app.js --bundle --target=es2016 --outdir=../../ui/priv/static/assets --external:/fonts/* --external:/images/*),
    cd: Path.expand("../../ui/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

key_retail = "../key_retail.bin" |> Path.expand(__DIR__) |> File.read!() |> Base.encode64()

config :amiibo_serialization,
  key_retail: key_retail

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
