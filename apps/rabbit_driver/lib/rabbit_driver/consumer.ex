defmodule RabbitDriver.Consumer do
  use GenServer
  use AMQP

  require Logger

  alias __MODULE__.Options

  @enforce_keys [:channel, :options]
  defstruct [:channel, :options]

  @type topic() :: binary()

  @type payload() :: map()

  @callback init(opts :: Options.t()) :: any()

  @callback handle_msg(topic(), payload()) :: :noreply | {:reply, payload()} | {:error, any()}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    opts = Options.new(opts)

    opts.module.init(opts)

    {:ok, conn} = Connection.open(opts.url)
    {:ok, chan} = Channel.open(conn)
    setup_queue(chan, opts)

    :ok = Basic.qos(chan, prefetch_count: opts.prefetch_count)

    # Register the GenServer process as a consumer
    {:ok, _consumer_tag} = Basic.consume(chan, opts.queue)

    state = %__MODULE__{channel: chan, options: opts}

    {:ok, state}
  end

  # Confirmation sent by the broker after registering this process as a consumer
  def handle_info({:basic_consume_ok, _meta}, state) do
    {:noreply, state}
  end

  # Sent by the broker when the consumer is unexpectedly cancelled (such as after a queue deletion)
  def handle_info({:basic_cancel, _meta}, state) do
    {:stop, :normal, state}
  end

  # Confirmation sent by the broker to the consumer process after a Basic.cancel
  def handle_info({:basic_cancel_ok, _meta}, state) do
    {:noreply, state}
  end

  def handle_info({:basic_deliver, payload, meta}, state) do
    consume(state, payload, meta)
    {:noreply, state}
  end

  ## Helpers

  defp setup_queue(chan, opts) do
    {:ok, _} = Queue.declare(chan, opts.dead_letter, durable: true)

    # Messages that cannot be delivered to any consumer in the main queue will be routed to the error queue
    {:ok, _} =
      Queue.declare(chan, opts.queue,
        durable: true,
        arguments: [
          {"x-dead-letter-exchange", :longstr, ""},
          {"x-dead-letter-routing-key", :longstr, opts.dead_letter}
        ]
      )

    :ok = Exchange.topic(chan, opts.exchange, durable: true)

    for t <- opts.topics do
      :ok = Queue.bind(chan, opts.queue, opts.exchange, routing_key: t)
    end
  end

  defp consume(
         %__MODULE__{options: opts, channel: channel},
         payload,
         meta = %{routing_key: topic, delivery_tag: tag}
       ) do
    topic = String.split(topic, ".")

    case opts.module.handle_msg(topic, decode(payload)) do
      :noreply ->
        :ok = Basic.ack(channel, tag)

      {:reply, payload} ->
        :ok = reply(channel, payload, meta)
        :ok = Basic.ack(channel, tag)

      {:error, reason} ->
        _ = Logger.error(inspect(reason), extra: %{meta: meta, payload: payload})
        :ok = Basic.reject(channel, tag, requeue: false)
    end
  rescue
    # Requeue unless it's a redelivered message.
    # This means we will retry consuming a message once in case of exception
    # before we give up and have it moved to the error queue
    #
    # You might also want to catch :exit signal in production code.
    # Make sure you call ack, nack or reject otherwise consumer will stop
    # receiving messages.
    exception ->
      _ =
        Logger.error("Failed to process message from #{topic}",
          extra: %{meta: meta, payload: payload, exception: inspect(exception)}
        )

      :ok = Basic.reject(channel, tag, requeue: not meta.redelivered)
  end

  defp decode("") do
    %{}
  end

  defp decode(payload) do
    Jason.decode!(payload)
  end

  defp encode(map = %{}) do
    Jason.encode!(map)
  end

  defp encode("" <> string) do
    string
  end

  defp reply(channel, payload, %{reply_to: queue, correlation_id: id})
       when is_binary(queue) and is_binary(id) do
    Basic.publish(channel, "", queue, encode(payload), correlation_id: id)
    :ok
  end

  defp reply(_state, payload, meta) do
    _ =
      Logger.error("Unable to send reply for topic #{meta.routing_key}",
        extra: %{payload: payload, meta: meta}
      )

    :error
  end
end
