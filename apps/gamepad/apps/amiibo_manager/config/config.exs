import Config

config :amiibo_manager,
  ecto_repos: [AmiiboManager.Repo]

config :amiibo_manager, AmiiboManager.Repo,
  adapter: Ecto.Adapters.SQLite3,
  database: "~/amiibo.sqlite"

import_config("#{config_env()}.exs")
