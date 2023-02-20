import Config

config :amiibo_manager, AmiiboManager.Repo,
  database: "/tmp/amiibo_manager_test.db",
  pool: Ecto.Adapters.SQL.Sandbox,
  show_sensitive_data_on_connection_error: true,
  log: false
