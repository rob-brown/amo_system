import Config

if System.get_env("PHX_SERVER") do
  config :ui, UiWeb.Endpoint, server: true
end

# config/runtime.exs is executed for all environments, including
# during releases. It is executed after compilation and before the
# system starts, so it is typically used to load production configuration
# and secrets from environment variables or elsewhere. Do not define
# any compile-time configuration in here, as it won't be applied.
# The block below contains prod specific runtime configuration.
if config_env() == :prod do
  # The secret key base is used to sign/encrypt cookies and other secrets.
  # A default value is used in config/dev.exs and config/test.exs but you
  # want to use a different value for prod and you most likely don't want
  # to check this value into version control, so we use an environment
  # variable instead.
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "splicepad.local"
  db = System.get_env("DB_PATH") || "amiibo.sqlite"

  config :amiibo_manager, AmiiboManager.Repo,
    adapter: Ecto.Adapters.SQLite3,
    database: db

  config :ui, UiWeb.Endpoint,
    url: [host: host, port: 4000],
    http: [
      # Enable IPv6 and bind on all interfaces.
      # Set it to  {0, 0, 0, 0, 0, 0, 0, 1} for local network only access.
      # See the documentation on https://hexdocs.pm/plug_cowboy/Plug.Cowboy.html
      # for details about using IPv6 vs IPv4 and loopback vs public addresses.
      port: 4000,
      ip: {0, 0, 0, 0, 0, 0, 0, 0},
    ],
    secret_key_base: secret_key_base
end

maybe_ipv6 = if System.get_env("ECTO_IPV6"), do: [:inet6], else: []

config :amiibo_manager, AmiiboManager.Repo,
  socket_options: maybe_ipv6


