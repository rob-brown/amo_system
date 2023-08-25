defmodule RabbitDriver.RabbitLoggerBackend do
  @behaviour :gen_event

  defstruct [:conn, :channel, :exchange, :level, :format, :metadata, :url]

  @impl :gen_event
  def init({__MODULE__, opts}) when is_list(opts) do
    config = configure_merge(Application.get_env(:logger, :rabbit_logger_backend), opts)
    {:ok, init(config, %__MODULE__{})}
  end

  def init(_) do
    config = Application.get_env(:logger, :rabbit_logger_backend)
    {:ok, init(config, %__MODULE__{})}
  end

  @impl :gen_event
  def handle_call({:configure, options}, state) do
    {:ok, :ok, configure(options, state)}
  end

  @impl :gen_event
  def handle_event({level, _gl, {Logger, msg, time, meta}}, state) do
    %{level: log_level, metadata: keys, channel: channel, exchange: exchange} = state

    {:erl_level, level} = List.keyfind(meta, :erl_level, 0, {:erl_level, level})

    if meets_level?(level, log_level) do
      metadata = take_metadata(meta, keys)
      topic = "log.#{level}"

      {{year, month, day}, {hour, minute, second, ms}} = time

      datetime =
        DateTime.new!(
          Date.new!(year, month, day),
          Time.new!(hour, minute, second, {ms * 1000, 3})
        )

      payload =
        Jason.encode!(%{
          msg: msg,
          timestamp: datetime,
          level: level,
          meta: encode_metadata(metadata)
        })

      AMQP.Basic.publish(channel, exchange, topic, payload)
    end

    {:ok, state}
  end

  def handle_event(:flush, state) do
    {:ok, state}
  end

  def handle_event(_, state) do
    {:ok, state}
  end

  @impl :gen_event
  def handle_info(_, state) do
    {:ok, state}
  end

  @impl :gen_event
  def code_change(_old_vsn, state, _extra) do
    {:ok, state}
  end

  @impl :gen_event
  def terminate(_reason, _state) do
    :ok
  end

  ## Helpers

  defp default_url() do
    System.get_env("AMQP_URL", "amqp://guest:guest@localhost:5672")
  end

  defp default_exchange() do
    System.get_env("AMQP_EXCHANGE", "rabbit_driver.topic")
  end

  defp configure(options, state) do
    config = configure_merge(Application.get_env(:logger, :rabbit_logger_backend), options)
    Application.put_env(:logger, :rabbit_logger_backend, config)
    init(config, state)
  end

  defp init(config, state) do
    level = Keyword.get(config, :level)
    format = Logger.Formatter.compile(Keyword.get(config, :format))
    metadata = Keyword.get(config, :metadata, [])
    url = Keyword.get(config, :url, default_url())
    exchange = Keyword.get(config, :exchange, default_exchange())
    {:ok, conn} = AMQP.Connection.open(url)
    {:ok, channel} = AMQP.Channel.open(conn)

    %{
      state
      | format: format,
        metadata: metadata,
        level: level,
        url: url,
        exchange: exchange,
        conn: conn,
        channel: channel
    }
  end

  defp configure_merge(env, options) do
    Keyword.merge(env, options, fn
      _, _v1, v2 -> v2
    end)
  end

  defp meets_level?(_lvl, nil) do
    true
  end

  defp meets_level?(lvl, :warn) do
    meets_level?(lvl, :warning)
  end

  defp meets_level?(lvl, min) do
    Logger.compare_levels(lvl, min) != :lt
  end

  defp take_metadata(metadata, :all) do
    metadata
  end

  defp take_metadata(metadata, keys) do
    Enum.reduce(keys, [], fn key, acc ->
      case Keyword.fetch(metadata, key) do
        {:ok, val} -> [{key, val} | acc]
        :error -> acc
      end
    end)
  end

  defp encode_metadata(meta) do
    meta
    |> Enum.filter(fn {k, v} -> valid_key?(k) and valid_value?(v) end)
    |> Map.new()
  end

  defp valid_key?(k) do
    is_binary(k) or is_atom(k)
  end

  defp valid_value?(v) when is_list(v) do
    Enum.all?(v, &valid_value?/1)
  end

  defp valid_value?(v) when is_map(v) do
    encode_metadata(v)
  end

  defp valid_value?(v) do
    is_binary(v) or is_atom(v) or is_number(v) or is_boolean(v)
  end
end
