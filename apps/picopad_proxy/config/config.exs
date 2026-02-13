# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

# Configure amiibo encryption keys
key_retail = Path.expand("../key_retail.bin", __DIR__) |> File.read!() |> Base.encode64()

config :amiibo_serialization,
  key_retail: key_retail

config :picopad_proxy,
  generators: [timestamp_type: :utc_datetime],
  ecto_repos: [AmiiboManager.Repo]

config :amiibo_manager,
  ecto_repos: [AmiiboManager.Repo]

config :amiibo_manager, AmiiboManager.Repo,
  adapter: Ecto.Adapters.SQLite3,
  database: Path.expand("~/picopad_proxy_amiibo.sqlite"),
  pool_size: 5,
  timeout: 60_000,
  busy_timeout: 5_000

# Configure the endpoint
config :picopad_proxy, PicopadProxyWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PicopadProxyWeb.ErrorHTML, json: PicopadProxyWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: PicopadProxy.PubSub,
  live_view: [signing_salt: "QX35Y0dj"]

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :picopad_proxy, PicopadProxy.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  picopad_proxy: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.12",
  picopad_proxy: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
