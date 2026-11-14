defmodule KAR.Machine do
  alias AmiiboSerialization.Amiibo

  @enforce_keys [:uid, :sram]
  defstruct [:uid, :sram]

  @uid_offset 468
  @sram_offset 960
  @code_offset 0x13
  @code_size 6

  def read(%Amiibo{
        binary:
          <<_::binary-size(@uid_offset), uid::binary-size(7), _::binary-size(485),
            sram::binary-size(64), _::binary>>
      }) do
    {:ok, %__MODULE__{uid: uid, sram: sram}}
  end

  def read(%Amiibo{}) do
    {:error, :not_v3}
  end

  def write(amiibo = %Amiibo{}, %__MODULE__{uid: uid, sram: sram}) do
    case Amiibo.format(amiibo) do
      :v3 ->
        {:ok,
         amiibo |> Amiibo.put_bytes(@uid_offset, uid) |> Amiibo.put_bytes(@sram_offset, sram)}

      _ ->
        {:error, :not_v3}
    end
  end

  def code(%__MODULE__{sram: sram}) do
    :binary.part(sram, @code_offset, @code_size)
  end
end
