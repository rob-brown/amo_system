defmodule AmiiboSerialization.Key do
  @enforce_keys [:hmac_key, :type_string, :rfu, :magic_bytes_size, :magic_bytes, :xor_pad]
  defstruct [:hmac_key, :type_string, :rfu, :magic_bytes_size, :magic_bytes, :xor_pad]

  def parse_file(file) do
    with {:ok, bin} <- file |> Path.expand() |> File.read() do
      parse_binary(bin)
    end
  end

  def parse_binary(bin) do
    with {:ok, data_key, bin} <- parse_part(bin),
         {:ok, tag_key, ""} <- parse_part(bin) do
      {:ok, data_key, tag_key}
    end
  end

  defp parse_part(
         <<hmac_key::binary-size(16), type::binary-size(14), rfu, magic_bytes_size,
           magic_bytes::binary-size(16), xor_pad::binary-size(32), rest::binary>>
       ) do
    key = %__MODULE__{
      hmac_key: hmac_key,
      type_string: type,
      rfu: rfu,
      magic_bytes_size: magic_bytes_size,
      magic_bytes: magic_bytes,
      xor_pad: xor_pad
    }

    {:ok, key, rest}
  end

  defp parse_part(_) do
    {:error, :bad_binary}
  end
end
