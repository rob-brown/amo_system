defmodule AmiiboSerialization.DerivedKey do
  @enforce_keys [:aes_key, :aes_iv, :hmac_key]
  defstruct [:aes_key, :aes_iv, :hmac_key]

  alias AmiiboSerialization.Key

  def new(key = %Key{}, internal) do
    internal
    |> calculate_seed()
    |> prepare_seed(key)
    |> generate_bytes(key)
    |> from_bytes()
  end

  defp calculate_seed(binary) do
    seed_start = :binary.part(binary, 0x29, 0x2)
    seed_middle = :binary.part(binary, 0x1D4, 0x8)
    seed_end = :binary.part(binary, 0x1E8, 0x20)

    {seed_start, seed_middle <> seed_middle, seed_end}
  end

  defp prepare_seed({seed_start, seed_middle, seed_end}, key = %Key{}) do
    type = key.type_string
    magic_bytes = String.trim_trailing(key.magic_bytes, "\0")

    rest =
      [seed_end, key.xor_pad]
      |> Enum.map(&:binary.bin_to_list/1)
      |> Enum.zip()
      |> Enum.map(fn {x, y} -> Bitwise.bxor(x, y) end)
      |> :binary.list_to_bin()

    pad_length = 16 - byte_size(magic_bytes)
    <<pad::binary-size(pad_length), _::bits>> = seed_start

    seed = <<type::binary, pad::binary, magic_bytes::binary, seed_middle::binary, rest::binary>>
    seed
  end

  defp generate_bytes(seed, key) do
    generate_bytes_step(seed, key, 0, <<>>)
  end

  defp generate_bytes_step(_, _, _, result) when byte_size(result) >= 48 do
    result
  end

  defp generate_bytes_step(seed, key = %Key{}, iteration, result) do
    with data = <<iteration::unsigned-big-size(16), seed::binary>>,
         bytes = :crypto.mac(:hmac, :sha256, key.hmac_key, data) do
      generate_bytes_step(seed, key, iteration + 1, result <> bytes)
    end
  end

  defp from_bytes(
         <<aes_key::binary-size(16), aes_iv::binary-size(16), hmac_key::binary-size(16), _::bits>>
       ) do
    %__MODULE__{aes_key: aes_key, aes_iv: aes_iv, hmac_key: hmac_key}
  end
end
