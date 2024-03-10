defmodule Proxy.RespParser do
  def parse(data) when is_binary(data) do
    parse_next(data)
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
