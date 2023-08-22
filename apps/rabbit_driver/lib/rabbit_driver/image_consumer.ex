defmodule RabbitDriver.ImageConsumer do
  @behaviour RabbitDriver.Consumer

  require Logger

  alias RabbitDriver.DataURL

  def start_link(opts) do
    defaults = [
      module: __MODULE__,
      topics: ["image.#"],
      queue: "image_consumer"
    ]

    opts = Keyword.merge(defaults, opts)
    RabbitDriver.Consumer.start_link(opts)
  end

  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  def image_dir() do
    Path.join(System.tmp_dir(), "rabbit-driver-images")
  end

  @impl RabbitDriver.Consumer
  def init(_opts) do
    _ = File.mkdir_p(image_dir())
  end

  @impl RabbitDriver.Consumer
  def handle_msg(~w"image list", _payload) do
    {:reply, %{images: images()}}
  end

  def handle_msg(~w"image get", payload) do
    images = images()
    name = Map.get(payload, "name")

    if name in images do
      bytes = name |> path() |> File.read!() |> DataURL.encode("image/png", :base64)

      response = %{
        image: %{
          name: name,
          size: byte_size(bytes),
          bytes: bytes
        }
      }

      {:reply, response}
    else
      {:reply, %{image: nil, error: "Not found"}}
    end
  end

  def handle_msg(~w"image put", %{"name" => name, "bytes" => bytes}) do
    case DataURL.decode(bytes) do
      {:ok, "image/png", _param, bytes} ->
        File.write!(path(name), bytes)
        :noreply

      {:ok, type, _param, _bytes} ->
        Logger.error("Got unsupported image type '#{type}'")
        :noreply

      _ ->
        Logger.error("Unknown image data received")
        :noreply
    end
  end

  def handle_msg(~w"image delete", %{"name" => name}) do
    path = path(name)

    if File.regular?(path) do
      File.rm!(path)
    end

    :noreply
  end

  def handle_msg(topic, _payload) do
    {:error, "Unknown message #{topic}"}
  end

  ## Helpers

  defp images() do
    File.ls!(image_dir())
  end

  defp path(name = <<c::utf8>> <> _) when c in [?., ?/] do
    raise "Unsafe file name #{name}"
  end

  defp path(name) do
    if String.ends_with?(name, ".png") do
      Path.join(image_dir(), name)
    else
      Path.join(image_dir(), name <> ".png")
    end
  end
end
