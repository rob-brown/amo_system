import Config

config :logger,
  level: :debug,
  backends: [:console, RabbitDriver.RabbitLoggerBackend],
  console: [
    level: :warning
  ],
  rabbit_logger_backend: [
    level: :debug,
    metadata: :all
  ]
