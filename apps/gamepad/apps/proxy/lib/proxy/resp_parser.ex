defmodule Proxy.RespParser do
  require Logger

  def parse_all(data) do
    parse_all(data, [])
  end

  defp parse_all("", result) do
    Enum.reverse(result)
  end

  defp parse_all(data, result) do
    case parse(data) do
      {:error, reason} ->
        [{:error, reason}]

      {item, rest} ->
        parse_all(rest, [item | result])
    end
  end

  def parse("") do
    nil
  end

  def parse(data) when is_binary(data) do
    try do
      parse_next(data)
    rescue
      e ->
        Logger.error("Failed to parse RESP: #{inspect(data)}")
        reraise e, __STACKTRACE__
    end
  end

  # Map
  defp parse_next("%" <> data) do
    {int, "\n" <> rest} = Integer.parse(data)

    if int <= 0 do
      {%{}, rest}
    else
      {list, rest} =
        Enum.reduce(1..int, {[], rest}, fn _, {list, rest} ->
          {key, new_rest} = parse_next(rest)
          {value, new_rest} = parse_next(new_rest)

          {[{key, value} | list], new_rest}
        end)

      {Map.new(list), rest}
    end
  end

  # List
  defp parse_next("*" <> data) do
    parse_list(data)
  end

  # Push
  defp parse_next(">" <> data) do
    {list, rest} = parse_list(data)

    {{:push, list}, rest}
  end

  # Integer
  defp parse_next(":" <> rest) do
    {int, "\n" <> new_rest} = Integer.parse(rest)

    {int, new_rest}
  end

  # Bulk String
  defp parse_next("$" <> rest) do
    {int, "\n" <> new_rest} = Integer.parse(rest)

    <<string::binary-size(int), "\n", new_rest::bits>> = new_rest

    {string, new_rest}
  end

  # Simple string
  defp parse_next("+" <> rest) do
    parse_simple_string(rest)
  end

  # Simple error
  defp parse_next("-" <> rest) do
    {string, rest} = parse_simple_string(rest)

    {{:error, string}, rest}
  end

  # Catch all
  defp parse_next(string) do
    Logger.error("Unknown string: #{inspect(string)}")
    {:error, :badarg}
  end

  defp parse_list(data) do
    {int, "\n" <> rest} = Integer.parse(data)

    if int <= 0 do
      {%{}, rest}
    else
      {list, rest} =
        Enum.reduce(1..int, {[], rest}, fn _, {list, rest} ->
          {item, new_rest} = parse_next(rest)
          {[item | list], new_rest}
        end)

      {Enum.reverse(list), rest}
    end
  end

  defp parse_simple_string(rest) do
    [string, new_rest] = String.split(rest, "\n", parts: 2)

    {string, new_rest}
  end
end
