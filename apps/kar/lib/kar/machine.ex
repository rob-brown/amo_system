defmodule KAR.Machine do
  alias AmiiboSerialization.Amiibo
  alias KAR.Machines

  @enforce_keys [:sram]
  defstruct [:sram, :name, :code]

  @sram_offset 960
  @code_offset 0x13
  @code_size 6

  def new(<<sram::binary-size(64)>>) do
    %__MODULE__{
      sram: sram,
      name: Machines.name(sram),
      code: :binary.part(sram, @code_offset, @code_size)
    }
  end

  def resolve(name) when is_atom(name) do
    with {:ok, sram} <- Machines.sram(name) do
      {:ok, new(sram)}
    else
      :error -> {:error, :unknown_machine}
    end
  end

  def resolve(<<_::binary-size(64)>> = sram) do
    {:ok, new(sram)}
  end

  def resolve(%__MODULE__{} = machine) do
    {:ok, machine}
  end

  def resolve(%Amiibo{} = amiibo) do
    read(amiibo)
  end

  def resolve(_other) do
    {:error, :invalid_machine}
  end

  def read(%Amiibo{binary: <<_::binary-size(@sram_offset), sram::binary-size(64), _::binary>>}) do
    {:ok, new(sram)}
  end

  def read(%Amiibo{}) do
    {:error, :not_v3}
  end

  def write(%Amiibo{} = amiibo, %__MODULE__{sram: sram}) do
    case Amiibo.format(amiibo) do
      :v3 -> {:ok, Amiibo.put_bytes(amiibo, @sram_offset, sram)}
      _ -> {:error, :not_v3}
    end
  end
end
