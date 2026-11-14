defmodule AmiiboSerialization.Format do
  @type t() :: :v2 | :v3

  @v3_size 2048
  @internal_size 520
  @reserved_offset 0x080
  @reserved_size 64
  @v3_unmanaged_offset 0x248

  @spec of_tag(binary()) :: t()
  def of_tag(<<0x04, _::binary-size(90), 0x03, _::binary>> = binary)
      when byte_size(binary) == @v3_size do
    :v3
  end

  def of_tag(_binary) do
    :v2
  end

  @spec of_decrypted(binary()) :: t()
  def of_decrypted(binary) when byte_size(binary) == @v3_size do
    :v3
  end

  def of_decrypted(_binary) do
    :v2
  end

  def hmac_offset(:v2), do: 0x080
  def hmac_offset(:v3), do: 0x0C0

  def app_data_offset(:v2), do: 0x0A0
  def app_data_offset(:v3), do: 0x0E0

  def tag_head_size(:v2), do: @internal_size
  def tag_head_size(:v3), do: @v3_unmanaged_offset

  def reserved_offset(), do: @reserved_offset

  def extract_tail(:v2, tag) do
    :binary.part(tag, @internal_size, byte_size(tag) - @internal_size)
  end

  def extract_tail(:v3, tag) do
    reserved = :binary.part(tag, @reserved_offset, @reserved_size)
    rest = :binary.part(tag, @v3_unmanaged_offset, byte_size(tag) - @v3_unmanaged_offset)
    reserved <> rest
  end

  def split_tail(:v2, tail) do
    {<<>>, tail}
  end

  def split_tail(:v3, <<reserved::binary-size(@reserved_size), rest::binary>>) do
    {reserved, rest}
  end
end
