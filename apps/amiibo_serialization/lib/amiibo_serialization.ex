defmodule AmiiboSerialization do
  alias AmiiboSerialization.ByteBuffer
  alias AmiiboSerialization.Key
  alias AmiiboSerialization.DerivedKey

  def decrypt_file!(in_path) do
    in_path
    |> Path.expand()
    |> File.read!()
    |> decrypt_binary!()
  end

  def decrypt_file(in_path, key_path) do
    with in_path = Path.expand(in_path),
         key_path = Path.expand(key_path),
         true <- File.exists?(in_path),
         true <- File.exists?(key_path),
         {:ok, bin} = File.read(in_path),
         {:ok, result} = decrypt_binary(bin, key_path) do
      {:ok, result}
    else
      {message, _} ->
        {:error, message}

      false ->
        {:error, :eexists}
    end
  end

  def decrypt_binary(binary) do
    with {:ok, data_key, tag_key} <- key_file() do
      decrypt_binary(binary, data_key, tag_key)
    end
  end

  def decrypt_binary!(binary) do
    {:ok, result} = decrypt_binary(binary)
    result
  end

  def decrypt_binary(binary, key_path) do
    with {:ok, data_key, tag_key} <- Key.parse_file(key_path) do
      decrypt_binary(binary, data_key, tag_key)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp decrypt_binary(binary, data_key = %Key{}, tag_key = %Key{}) do
    <<internal::binary-size(520)>> = tag_to_internal(binary)
    derived_data_key = DerivedKey.new(data_key, internal)
    derived_tag_key = DerivedKey.new(tag_key, internal)
    buffer = ByteBuffer.from_binary(internal)
    buffer = cipher(derived_data_key, buffer)
    tag_bin = ByteBuffer.slice(buffer, 0x1D4, 0x34)
    tag_hash = :crypto.mac(:hmac, :sha256, derived_tag_key.hmac_key, tag_bin)
    buffer = ByteBuffer.set(buffer, 0x1B4, tag_hash)
    data_bin = ByteBuffer.slice(buffer, 0x29, 0x1DF)
    data_hash = :crypto.mac(:hmac, :sha256, derived_data_key.hmac_key, data_bin)
    buffer = ByteBuffer.set(buffer, 0x8, data_hash)
    original_data_hash = :binary.part(internal, 0x8, 0x20)
    original_tag_hash = :binary.part(internal, 0x1B4, 0x20)

    if original_data_hash == data_hash and original_tag_hash == tag_hash do
      result = ByteBuffer.to_binary(buffer) <> :binary.part(binary, 520, byte_size(binary) - 520)
      {:ok, result}
    else
      {:error, :bad_hash}
    end
  end

  def encrypt_binary!(binary) do
    {:ok, data_key, tag_key} = key_file()
    {:ok, result} = encrypt_binary(binary, data_key, tag_key)
    result
  end

  def encrypt_binary(binary, key_path) do
    with {:ok, data_key, tag_key} <- Key.parse_file(key_path) do
      encrypt_binary(binary, data_key, tag_key)
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp encrypt_binary(binary, data_key = %Key{}, tag_key = %Key{}) do
    derived_data_key = DerivedKey.new(data_key, binary)
    derived_tag_key = DerivedKey.new(tag_key, binary)
    buffer = ByteBuffer.from_binary(binary)
    tag_bin = ByteBuffer.slice(buffer, 0x1D4, 0x34)
    tag_hash = :crypto.mac(:hmac, :sha256, derived_tag_key.hmac_key, tag_bin)

    data_bin =
      ByteBuffer.slice(buffer, 0x29, 0x18B) <> tag_hash <> ByteBuffer.slice(buffer, 0x1D4, 0x34)

    data_hash = :crypto.mac(:hmac, :sha256, derived_data_key.hmac_key, data_bin)
    buffer = cipher(derived_data_key, buffer)
    buffer = ByteBuffer.set(buffer, 0x1B4, tag_hash)
    buffer = ByteBuffer.set(buffer, 0x8, data_hash)
    tail = :binary.part(binary, 520, byte_size(binary) - 520)
    result = internal_to_tag(ByteBuffer.to_binary(buffer)) <> tail
    {:ok, result}
  end

  defp key_file() do
    key_file_from_config() || key_file_from_env()
  end

  defp key_file_from_config() do
    with <<bin::binary>> <- Application.get_env(:amiibo_serialization, :key_retail),
         {:ok, decoded} <- Base.decode64(bin),
         {:ok, data_key, tag_key} <- Key.parse_binary(decoded) do
      {:ok, data_key, tag_key}
    else
      _ ->
        nil
    end
  end

  defp key_file_from_env() do
    with <<bin::binary>> <- System.get_env("KEY_RETAIL"),
         {:ok, decoded} <- Base.decode64(bin),
         {:ok, data_key, tag_key} <- Key.parse_binary(decoded) do
      {:ok, data_key, tag_key}
    else
      _ ->
        nil
    end
  end

  def encrypted?(<<0x04, uid1, uid2, bcc0, uid3, uid4, uid5, uid6, bcc1, _::bits>>) do
    expected_bcc0 = Enum.reduce([0x04, uid1, uid2, 0x88], &Bitwise.bxor/2)
    expected_bcc1 = Enum.reduce([uid3, uid4, uid5, uid6], &Bitwise.bxor/2)

    expected_bcc0 == bcc0 and expected_bcc1 == bcc1
  end

  def encrypted?(
        <<bcc1, _::binary-size(467), 0x04, uid1, uid2, bcc0, uid3, uid4, uid5, uid6, _::bits>>
      ) do
    expected_bcc0 = Enum.reduce([0x04, uid1, uid2, 0x88], &Bitwise.bxor/2)
    expected_bcc1 = Enum.reduce([uid3, uid4, uid5, uid6], &Bitwise.bxor/2)

    not (expected_bcc0 == bcc0 and expected_bcc1 == bcc1)
  end

  def encrypted?(_) do
    {:error, :invalid}
  end

  def decrypted?(binary) do
    case encrypted?(binary) do
      true ->
        false

      false ->
        true

      error ->
        error
    end
  end

  defp tag_to_internal(binary) do
    ByteBuffer.fixed(520, fill: 0)
    |> ByteBuffer.set(0x000, :binary.part(binary, 0x008, 0x008))
    |> ByteBuffer.set(0x008, :binary.part(binary, 0x080, 0x020))
    |> ByteBuffer.set(0x028, :binary.part(binary, 0x010, 0x024))
    |> ByteBuffer.set(0x04C, :binary.part(binary, 0x0A0, 0x168))
    |> ByteBuffer.set(0x1B4, :binary.part(binary, 0x034, 0x020))
    |> ByteBuffer.set(0x1D4, :binary.part(binary, 0x000, 0x008))
    |> ByteBuffer.set(0x1DC, :binary.part(binary, 0x054, 0x02C))
    |> ByteBuffer.to_binary()
  end

  defp internal_to_tag(binary) do
    ByteBuffer.fixed(520, fill: 0)
    |> ByteBuffer.set(0x008, :binary.part(binary, 0x000, 0x008))
    |> ByteBuffer.set(0x080, :binary.part(binary, 0x008, 0x020))
    |> ByteBuffer.set(0x010, :binary.part(binary, 0x028, 0x024))
    |> ByteBuffer.set(0x0A0, :binary.part(binary, 0x04C, 0x168))
    |> ByteBuffer.set(0x034, :binary.part(binary, 0x1B4, 0x020))
    |> ByteBuffer.set(0x000, :binary.part(binary, 0x1D4, 0x008))
    |> ByteBuffer.set(0x054, :binary.part(binary, 0x1DC, 0x02C))
    |> ByteBuffer.to_binary()
  end

  defp cipher(key, buffer) do
    with text = ByteBuffer.slice(buffer, 0x2C, 0x188),
         decrypted = :crypto.crypto_one_time(:aes_128_ctr, key.aes_key, key.aes_iv, text, false) do
      ByteBuffer.fixed(520, fill: 0)
      |> ByteBuffer.set(0x2C, decrypted)
      |> ByteBuffer.set(0x0, ByteBuffer.slice(buffer, 0x0, 0x8))
      |> ByteBuffer.set(0x28, ByteBuffer.slice(buffer, 0x28, 0x4))
      |> ByteBuffer.set(0x1D4, ByteBuffer.slice(buffer, 0x1D4, 0x34))
    end
  end
end
