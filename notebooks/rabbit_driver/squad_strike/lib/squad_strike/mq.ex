defmodule SquadStrike.MQ do
  use Agent

  @name __MODULE__

  @enforce_keys [:conn, :channel, :exchange]
  defstruct [:conn, :channel, :exchange]

  def start_link(_) do
    url = System.get_env("AMQP_URL", "amqp://guest:guest@localhost:5672")
    exchange = System.get_env("AMQP_EXCHANGE", "rabbit_driver.topic")

    Agent.start_link(
      fn ->
        {:ok, conn} = AMQP.Connection.open(url)
        {:ok, channel} = AMQP.Channel.open(conn)

        %__MODULE__{conn: conn, channel: channel, exchange: exchange}
      end,
      name: @name
    )
  end

  def cast(agent \\ @name, topic, payload = %{}) do
    cast(channel, exchange, topic, Jason.encode!(payload))
  end

  def cast(agent \\ @name, topic, "" <> payload) do
    %__MODULE{channel: channel, exchange: exchange} = Agent.get(agent, & &1)

    AMQP.Basic.publish(channel, exchange, topic, payload)
  end

  def call(agent \\ @name, topic, payload, opts \\ [])

  def call(agent, topic, payload = %{}, opts) do
    call(channel, exchange, topic, Jason.encode!(payload), opts)
  end

  def call(agent, topic, "" <> payload, opts) do
    id =
      :erlang.unique_integer()
      |> :erlang.integer_to_binary()
      |> Base.encode64()

    timeout = Keyword.get(opts, :timeout_ms, :timer.seconds(5))
    reply_queue = Keyword.get(opts, :reply_to)

    queue =
      if reply_queue do
        reply_queue
      else
        {:ok, %{queue: queue}} =
          AMQP.Queue.declare(channel, "", exclusive: true, auto_delete: true)

        queue
      end

    me = self()

    {:ok, tag} =
      AMQP.Queue.subscribe(channel, queue, fn
        payload, meta = %{correlation_id: ^id} ->
          send(me, {:ok, payload, meta})

        _payload, _meta ->
          :ok
      end)

    AMQP.Basic.publish(channel, exchange, topic, payload,
      reply_to: queue,
      correlation_id: id
    )

    await(channel, tag, timeout)
  end

  def run_script(agent \\ @name, script, opts \\ []) do
    inputs = Keyword.get(opts, :inputs, [])
    timeout = Keyword.get(opts, :timeout_ms, :timer.seconds(5))

    call(
      "script.run",
      %{
        name: script,
        inputs: inputs,
        timeout_ms: timeout
      },
      timeout_ms: timeout
    )
  end

  def setup(agent \\ @name) do
    load_scripts(agent)
    load_images(agent)
  end

  ## Helpers

  defp load_scripts(agent \\ @name) do
    for %{name: name, path: path} <- files("scripts", ".lua") do
      cast("script.put", %{
        name: name,
        bytes: File.read!(path)
      })
    end
  end

  defp load_images(agent \\ @name) do
    for %{name: name, path: path} <- files("images", ".png") do
      cast("image.put", %{
        name: name,
        bytes: File.read!(path)
      })
    end
  end

  defp files(subdir, extension) do
    priv = :code.priv_dir(:squad_strike)
    dir = Path.expand(subdir, priv)

    dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, extension))
    |> Enum.map(&%{name: &1, path: Path.join(dir, &1)})
  end

  defp await(channel, tag, timeout) do
    receive do
      {:ok, payload, meta} ->
        AMQP.Queue.unsubscribe(channel, tag)
        json = Jason.decode!(payload)
        {:ok, json, meta}

      _ ->
        await(channel, tag, timeout)
    after
      timeout ->
        AMQP.Queue.unsubscribe(channel, tag)
        {:error, :timeout}
    end
  end
end
