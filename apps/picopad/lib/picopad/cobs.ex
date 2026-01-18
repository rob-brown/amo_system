defmodule Picopad.COBS do
  @delimiter 0x00
  @max_block_size 254

  def encode(<<>>), do: <<>>

  def encode(data) when is_binary(data) do
    do_encode(data, <<>>, <<>>, 1)
  end

  defp do_encode(<<>>, block, acc, code) do
    acc <> <<code>> <> block
  end

  defp do_encode(<<@delimiter, rest::binary>>, block, acc, code) do
    do_encode(rest, <<>>, acc <> <<code>> <> block, 1)
  end

  defp do_encode(<<byte, rest::binary>>, block, acc, code) when code == @max_block_size do
    do_encode(rest, <<byte>>, acc <> <<0xFF>> <> block, 2)
  end

  defp do_encode(<<byte, rest::binary>>, block, acc, code) do
    do_encode(rest, block <> <<byte>>, acc, code + 1)
  end

  def decode(<<>>), do: {:ok, <<>>}

  def decode(data) when is_binary(data) do
    do_decode(data, <<>>)
  end

  defp do_decode(<<>>, acc), do: {:ok, acc}

  defp do_decode(<<code, rest::binary>>, acc) when code > 0 do
    bytes_to_read = code - 1

    if byte_size(rest) < bytes_to_read do
      {:error, :incomplete}
    else
      <<segment::binary-size(bytes_to_read), remaining::binary>> = rest

      new_acc =
        if code < 0xFF and remaining != <<>> do
          acc <> segment <> <<@delimiter>>
        else
          acc <> segment
        end

      do_decode(remaining, new_acc)
    end
  end

  defp do_decode(<<_code, _rest::binary>>, _acc), do: {:error, :invalid_cobs}
end
