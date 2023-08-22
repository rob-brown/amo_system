defmodule RabbitDriver.DataURL do
  @doc """
  Decodes a [Data URL](https://developer.mozilla.org/en-US/docs/web/http/basics_of_http/data_urls).

      iex> RabbitDriver.DataURL.decode("data:,Hello%2C%20World%21")
      {:ok, "text/plain", "charset=US-ASCII", "Hello, World!"}

      iex> RabbitDriver.DataURL.decode("data:text/plain;base64,SGVsbG8sIFdvcmxkIQ==")
      {:ok, "text/plain", "", "Hello, World!"}

      iex> RabbitDriver.DataURL.decode("data:text/plain;charset=UTF-8;base64,SGVsbG8sIFdvcmxkIQ==")
      {:ok, "text/plain", "charset=UTF-8", "Hello, World!"}

      iex> RabbitDriver.DataURL.decode("data:text/html,%3Ch1%3EHello%2C%20World%21%3C%2Fh1%3E")
      {:ok, "text/html", "", "<h1>Hello, World!</h1>"}
  """
  def decode("data:" <> rest) do
    {type, param, encoding, data} = parse_headers(rest)
    decoded = decode(data, encoding)

    {:ok, type, param, decoded}
  end

  def decode(_other) do
    {:error, :not_url}
  end

  @doc """
  Encodes the given data as a data URL.

      iex> RabbitDriver.DataURL.encode("Hello, World!", "", :url)
      "data:,Hello%2C%20World!"

      iex> RabbitDriver.DataURL.encode("Hello, World!", "text/plain", :url)
      "data:text/plain,Hello%2C%20World!"

      iex> RabbitDriver.DataURL.encode("Hello, World!", "text/plain;charset=UTF-8", :base64)
      "data:text/plain;charset=UTF-8;base64,SGVsbG8sIFdvcmxkIQ=="
  """
  def encode(data, type, :base64) do
    "data:#{type};base64,#{Base.encode64(data)}"
  end

  def encode(data, type, :url) do
    "data:#{type},#{URI.encode(data, &char_unescaped?/1)}"
  end

  ## Helpers

  defp parse_headers(string) do
    [headers, data] = String.split(string, ",", parts: 2)

    cond do
      headers == "" ->
        {"text/plain", "charset=US-ASCII", :url, data}

      String.ends_with?(headers, ";base64") ->
        {type, param} = headers |> String.replace_suffix(";base64", "") |> parse_media_type()

        {type, param, :base64, data}

      true ->
        {type, param} = parse_media_type(headers)

        {type, param, :url, data}
    end
  end

  defp parse_media_type(string) do
    case String.split(string, ";", parts: 2) do
      [type] ->
        {type, ""}

      [type, param] ->
        {type, param}
    end
  end

  defp decode(data, :base64) do
    Base.decode64!(data)
  end

  defp decode(data, :url) do
    URI.decode(data)
  end

  defp char_unescaped?(?,) do
    false
  end

  defp char_unescaped?(other) do
    URI.char_unescaped?(other)
  end
end
