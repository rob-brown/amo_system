defmodule KAR.Machines do
  @machines %{
    warp_star:
      "02007d5a37e4b65c200bb60bcdec9a008200035042345731372001010200000000000000000000000000000000000000000000000000000000000000000089b8",
    shadow_star:
      "020014d10cd4e3443c0aaebf9b0aa30081000a50423554343220010104000000000000000000000000000000000000000000000000000000000000000000940b",
    tank_star:
      "02009707cf710471e95cf080823b31004a0011504336553535200101040000000000000000000000000000000000000000000000000000000000000000002e2b"
  }

  @sram Map.new(@machines, fn {name, hex} -> {name, Base.decode16!(hex, case: :lower)} end)

  def names do
    @sram |> Map.keys() |> Enum.sort()
  end

  def sram(name) when is_atom(name) do
    Map.fetch(@sram, name)
  end

  def name(<<_::binary-size(64)>> = sram) do
    Enum.find_value(@sram, fn
      {name, ^sram} -> name
      _ -> nil
    end)
  end
end
