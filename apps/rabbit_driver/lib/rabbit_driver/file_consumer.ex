defmodule RabbitDriver.FileConsumer do
  @behaviour RabbitDriver.Consumer

  def start_link(opts) do
    defaults = [
      module: __MODULE__,
      topics: ["image.#", "script.list", "script.get", "script.put", "script.delete"],
      queue: "file_consumer"
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

  @impl RabbitDriver.Consumer
  def init(_opts) do
    _ = File.mkdir_p(image_dir())
    _ = File.mkdir_p(script_dir())
  end

  @impl RabbitDriver.Consumer
  def handle_msg(~w"image list", _payload) do
    {:reply, %{images: images()}}
  end

  def handle_msg(~w"script list", _payload) do
    {:reply, %{scripts: scripts()}}
  end

  def handle_msg([type = "image", "get"], payload) do
    images = images()
    name = Map.get(payload, "name")

    if name in images do
      bytes = name |> path(type) |> File.read!() |> Base.encode64()

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

  def handle_msg([type = "script", "get"], payload) do
    scripts = scripts()
    name = Map.get(payload, "name")

    if name in scripts do
      bytes = name |> path(type) |> File.read!() |> Base.encode64()

      response = %{
        script: %{
          name: name,
          size: byte_size(bytes),
          bytes: bytes
        }
      }

      {:reply, response}
    else
      {:reply, %{script: nil, error: "Not found"}}
    end
  end

  def handle_msg([type, "put"], %{"name" => name, "bytes" => bytes}) do
    bytes = Base.decode64!(bytes)
    File.write!(path(name, type), bytes)
    :noreply
  end

  def handle_msg([type, "delete"], %{"name" => name}) do
    path = path(name, type)

    if File.regular?(path) do
      File.rm!(path)
    end

    :noreply
  end

  def handle_msg(topic, _payload) do
    {:error, "Unknown message #{topic}"}
  end

  ## Helpers

  defp image_dir() do
    Path.join(System.tmp_dir(), "rabbit-driver-images")
  end

  defp script_dir() do
    Path.join(System.tmp_dir(), "rabbit-driver-scripts")
  end

  defp images() do
    File.ls!(image_dir())
  end

  defp scripts() do
    File.ls!(script_dir())
  end

  defp path(name = <<c::utf8>> <> _, _type) when c in [?., ?/] do
    raise "Unsafe file name #{name}"
  end

  defp path(name, "image") do
    Path.join(image_dir(), name)
  end

  defp path(name, "script") do
    Path.join(script_dir(), name)
  end
end
