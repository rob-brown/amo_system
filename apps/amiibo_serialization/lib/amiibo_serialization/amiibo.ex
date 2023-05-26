defmodule AmiiboSerialization.Amiibo do
  @enforce_keys [:binary]
  defstruct [:binary]

  require Logger

  alias AmiiboSerialization.ByteBuffer
  alias AmiiboSerialization.CRC32
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

  def bytes(%__MODULE__{binary: binary}, lo..hi) do
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

  def set_serial(%__MODULE__{binary: binary}, serial) do
    <<partial_uid::binary-size(8), bcc1>> = UID.write(serial)

    binary
    |> ByteBuffer.from_binary()
    |> ByteBuffer.set(468, partial_uid)
    |> ByteBuffer.set(0, <<bcc1>>)
    |> ByteBuffer.to_binary()
    |> new()
  end

  def serial_number(%__MODULE__{binary: binary}) do
    <<_::binary-size(468), uid::binary-size(9), _::bits>> = binary
    UID.read(uid)
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

  defp decrypt(binary) do
    if AmiiboSerialization.encrypted?(binary) do
      AmiiboSerialization.decrypt_binary(binary)
    else
      {:ok, binary}
    end
  end
end
