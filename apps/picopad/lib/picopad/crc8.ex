defmodule Picopad.CRC8 do
  @polynomial 0x07
  @init 0x00

  def calculate(data) when is_binary(data) do
    data
    |> :binary.bin_to_list()
    |> Enum.reduce(@init, &update/2)
  end

  defp update(byte, crc) do
    crc = Bitwise.bxor(crc, byte)

    Enum.reduce(0..7, crc, fn _, acc ->
      if Bitwise.band(acc, 0x80) != 0 do
        Bitwise.band(Bitwise.bsl(acc, 1) |> Bitwise.bxor(@polynomial), 0xFF)
      else
        Bitwise.band(Bitwise.bsl(acc, 1), 0xFF)
      end
    end)
  end
end
