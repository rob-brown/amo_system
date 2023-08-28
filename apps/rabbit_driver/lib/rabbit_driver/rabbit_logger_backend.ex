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

      data = %{
        msg: encode_string(msg),
        timestamp: datetime,
        level: level,
        meta: encode_metadata(metadata)
      }

      payload = Jason.encode!(data)

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

  defguardp is_json_literal(v) when is_number(v) or is_binary(v) or is_atom(v) or is_boolean(v)

  defguardp is_json_incompatible(v)
            when is_port(v) or is_reference(v) or is_pid(v) or is_function(v)

  defp encode_string(string) when is_binary(string) do
    string
  end

  defp encode_string(list) when is_list(list) do
    IO.iodata_to_binary(list)
  end

  defp encode_metadata(meta = %struct{}) do
    meta
    |> Map.from_struct()
    |> Map.put("struct_name", struct)
    |> encode_metadata()
  end

  defp encode_metadata(meta) do
    for {k, v} <- meta, mapped = map_pair(k, v), mapped != :skip, into: %{} do
      mapped
    end
  end

  defp map_pair(k, _v) when not is_binary(k) and not is_atom(k) do
    :skip
  end

  defp map_pair(k, v) do
    {k, map_item(v)}
  end

  defp map_item(v) when is_map(v) do
    encode_metadata(v)
  end

  defp map_item(v) when is_list(v) do
    if improper_list?(v) do
      # Assumes any improper lists are iodata.
      IO.iodata_to_binary(v)
    else
      Enum.map(v, &map_item/1)
    end
  end

  defp map_item(v) when is_json_literal(v) do
    v
  end

  defp map_item(v) when is_json_incompatible(v) do
    # Convert the item to a string.
    inspect(v)
  end

  defp map_item(v) when is_tuple(v) do
    v |> Tuple.to_list() |> Enum.map(&map_item/1)
  end

  def improper_list?([]) do
    false
  end

  def improper_list?([_head | tail]) when not is_list(tail) do
    true
  end

  def improper_list?([head | tail]) when is_list(head) and is_list(tail) do
    improper_list?(head) or improper_list?(tail)
  end

  def improper_list?([_head | tail]) do
    improper_list?(tail)
  end
end
