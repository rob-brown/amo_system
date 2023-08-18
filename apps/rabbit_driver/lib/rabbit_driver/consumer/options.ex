defmodule RabbitDriver.Consumer.Options do
  @enforce_keys [:module, :topics, :queue]
  defstruct [:module, :url, :topics, :exchange, :queue, :dead_letter, :prefetch_count]

  @type t() :: %__MODULE__{
          module: atom(),
          url: binary(),
          topics: binary(),
          exchange: binary(),
          queue: binary(),
          dead_letter: binary(),
          prefetch_count: integer()
        }

  def new(opts) when is_list(opts) do
    topics = Keyword.get(opts, :topics)

    if Keyword.get(opts, :module) == nil do
      raise "Missing module"
    end

    if topics == nil or topics == [] do
      raise "Missing topics"
    end

    if Keyword.get(opts, :queue) == nil do
      raise "Missing queue"
    end

    opts = Keyword.merge(defaults(opts), opts)
    struct(__MODULE__, opts)
  end

  def new(opts = %__MODULE__{}) do
    opts
  end

  defp defaults(opts) do
    queue = Keyword.get(opts, :queue)
    dead_letter = "#{queue}_error"

    [
      url: default_url(),
      exchange: default_exchange(),
      dead_letter: dead_letter,
      prefetch_count: 1
    ]
  end

  defp default_url() do
    System.get_env("AMQP_URL", "amqp://guest:guest@localhost:5672")
  end

  defp default_exchange() do
    System.get_env("AMQP_EXCHANGE", "rabbit_driver.topic")
  end
end
