defmodule AmiiboSerialization.Amiibo do
  @enforce_keys [:binary]
  defstruct [:binary]

  require Logger

  alias AmiiboSerialization.ByteBuffer
  alias AmiiboSerialization.CRC32
  alias AmiiboSerialization.Format
  alias AmiiboSerialization.UID

  def new(<<binary::binary-size(540)>>) do
    %__MODULE__{binary: binary}
  end

  def new(<<binary::binary-size(532)>>) do
    %__MODULE__{binary: binary}
  end

  def new(<<binary::binary-size(540), _::binary-size(32)>>) do
    %__MODULE__{binary: binary}
  end

  def new(<<binary::binary-size(2048)>>) do
    %__MODULE__{binary: binary}
  end

  def format(%__MODULE__{binary: binary}) do
    Format.of_decrypted(binary)
  end

  def read_file(path) do
    with {:ok, binary} <- path |> Path.expand() |> File.read(),
         {:ok, result} <- read_string(binary) do
      {:ok, result}
    else
      {:error, reason} ->
        Logger.error("Failed to parse #{inspect(path)}")
        {:error, reason}
    end
  end

  def read_string(binary) do
    with {:ok, decrypted} <- decrypt(binary),
         amiibo = new(decrypted) do
      {:ok, amiibo}
    end
  end

  def bytes(%__MODULE__{binary: binary}, lo..hi//_) do
    length = hi - lo + 1
    <<_::binary-size(lo), value::binary-size(length), _::bits>> = binary
    value
  end

  def app_id(%__MODULE__{binary: binary}) do
    <<id::unsigned-big-size(32)>> =
      binary
      |> ByteBuffer.from_binary()
      |> ByteBuffer.slice(182, 4)

    id
  end

  def program_id(%__MODULE__{binary: binary}) do
    <<id::unsigned-big-size(64)>> =
      binary
      |> ByteBuffer.from_binary()
      |> ByteBuffer.slice(172, 8)

    id
  end

  def owner_name(amiibo) do
    amiibo
    |> bytes(102..121)
    |> :unicode.characters_to_binary({:utf16, :little})
    |> case do
      <<name::binary>> ->
        name
        |> String.split("\0", parts: 2)
        |> Enum.at(0)

      _ ->
        "[Bad Name]"
    end
  end

  def nickname(amiibo) do
    amiibo
    |> bytes(56..75)
    |> :unicode.characters_to_binary({:utf16, :big})
    |> case do
      <<name::binary>> ->
        name
        |> String.split("\0", parts: 2)
        |> Enum.at(0)

      _ ->
        "[Bad Name]"
    end
  end

  def rename(amiibo, name) do
    name =
      name
      |> :unicode.characters_to_binary(:utf8, :utf16)
      |> (&(&1 <> <<0::integer-size(160)>>)).()
      |> :binary.part(0, 20)

    amiibo.binary
    |> ByteBuffer.from_binary()
    |> ByteBuffer.set(56, name)
    |> ByteBuffer.to_binary()
    |> new()
  end

  def shuffle_serial(a = %__MODULE__{}) do
    set_serial(a, UID.random())
  end

  def set_serial(amiibo = %__MODULE__{binary: binary}, serial) do
    binary
    |> ByteBuffer.from_binary()
    |> write_uid(format(amiibo), serial)
    |> ByteBuffer.to_binary()
    |> new()
  end

  def serial_number(amiibo = %__MODULE__{binary: binary}) do
    case format(amiibo) do
      :v2 ->
        <<_::binary-size(468), uid::binary-size(9), _::bits>> = binary
        UID.read(uid)

      :v3 ->
        <<_::binary-size(468), uid::binary-size(7), _::bits>> = binary
        uid
    end
  end

  def mii_profile(%__MODULE__{binary: binary}) do
    <<_::binary-size(100), mii_bytes::binary-size(48), _::bits>> = binary
    mii_bytes
  end

  def update_hash(%__MODULE__{binary: binary}) do
    checksum = CRC32.sign(binary)

    binary
    |> ByteBuffer.from_binary()
    |> ByteBuffer.set(220, <<checksum::unsigned-little-size(32)>>)
    |> ByteBuffer.to_binary()
    |> new()
  end

  def amiibo_id(%__MODULE__{binary: <<_::binary-size(476), id::binary-size(8), _::bits>>}) do
    id
  end

  def set_id(%__MODULE__{binary: binary}, id) when is_binary(id) and byte_size(id) == 8 do
    binary
    |> ByteBuffer.from_binary()
    |> ByteBuffer.set(476, id)
    |> ByteBuffer.to_binary()
    |> new()
  end

  ## Helpers

  defp write_uid(buffer, :v2, serial) do
    <<partial_uid::binary-size(8), bcc1>> = UID.write(serial)

    buffer
    |> ByteBuffer.set(468, partial_uid)
    |> ByteBuffer.set(0, <<bcc1>>)
  end

  defp write_uid(buffer, :v3, serial) do
    ByteBuffer.set(buffer, 468, UID.read(UID.write(serial)))
  end

  defp decrypt(binary) do
    if AmiiboSerialization.encrypted?(binary) do
      AmiiboSerialization.decrypt_binary(binary)
    else
      {:ok, binary}
    end
  end
end
