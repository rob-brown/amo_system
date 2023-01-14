defmodule AmiiboSerialization.CRC32 do
  import Bitwise

  require Integer

  def sign(binary) do
    binary
    |> :binary.part(0xE0, 0xD4)
    |> calc0(calculate_u0(), 0x0, 0xFFFFFFFF)
  end

  ## Helpers

  defp calculate_u0(input \\ 0xEDB88320) do
    p0 = input ||| 0x80000000
    Enum.map(0..255, &calc_step(&1, p0))
  end

  defp calc0(binary, u0, in_xor, out_xor) do
    array = :array.from_list(u0)

    binary
    |> :binary.bin_to_list()
    |> Enum.reduce(in_xor, fn x, acc ->
      index = Bitwise.bxor(x, acc &&& 0xFF)
      Bitwise.bxor(acc >>> 8, :array.get(index, array))
    end)
    |> Bitwise.bxor(out_xor)
  end

  defp calc_step(n, p0) do
    Enum.reduce(1..8, n, fn _, acc ->
      if Integer.is_odd(acc) do
        Bitwise.bxor(acc >>> 1, p0)
      else
        acc >>> 1
      end
    end)
  end
end
