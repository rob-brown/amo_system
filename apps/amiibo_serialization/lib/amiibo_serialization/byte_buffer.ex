defmodule AmiiboSerialization.ByteBuffer do
  @enforce_keys [:buffer]
  defstruct [:buffer]

  defguardp is_byte(byte) when is_integer(byte) and byte >= 0x00 and byte <= 0xFF

  defguardp is_array(array) when is_tuple(array) and elem(array, 0) == :array

  defguardp is_index(index) when is_integer(index) and index >= 0

  def new() do
    new(:array.new())
  end

  defp new(array) when is_array(array) do
    %__MODULE__{buffer: array}
  end

  def fixed(size) do
    fixed(size, fill: 0)
  end

  def fixed(size, fill: fill) when is_byte(fill) do
    :array.new(size, default: fill) |> new()
  end

  def get(%__MODULE__{buffer: buffer}, index) when is_index(index) do
    :array.get(index, buffer)
  end

  def slice(buffer, lo..hi//_) do
    lo..hi
    |> Enum.map(&get(buffer, &1))
    |> :binary.list_to_bin()
  end

  def slice(buffer, offset, length) do
    slice(buffer, offset..(offset + length - 1))
  end

  def set(%__MODULE__{buffer: buffer}, index, value) when is_index(index) and is_byte(value) do
    :array.set(index, value, buffer) |> new()
  end

  def set(buffer, _index, <<>>) do
    buffer
  end

  def set(%__MODULE__{buffer: buffer}, index, <<byte, rest::binary>>) do
    :array.set(index, byte, buffer)
    |> new()
    |> set(index + 1, rest)
  end

  def from_binary(binary) when is_binary(binary) do
    binary
    |> :binary.bin_to_list()
    |> :array.from_list()
    |> new()
  end

  def to_binary(%__MODULE__{buffer: buffer}) do
    buffer
    |> :array.to_list()
    |> :binary.list_to_bin()
  end
end

defimpl Enumerable, for: AmiiboSerialization.ByteBuffer do
  def count(%@for{buffer: buffer}) do
    {:ok, :array.size(buffer)}
  end

  def member?(_, _) do
    {:error, __MODULE__}
  end

  def slice(_) do
    {:error, __MODULE__}
  end

  def reduce(%@for{buffer: buffer}, acc, fun) do
    Enumerable.List.reduce(:array.to_list(buffer), acc, fun)
  end
end
