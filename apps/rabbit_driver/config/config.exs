import Config

config :logger,
  level: :debug,
  backends: [:console, RabbitDriver.RabbitLoggerBackend],
  console: [
    level: :debug
  ],
  rabbit_logger_backend: [
    level: :debug,
    metadata: :all
  ]
