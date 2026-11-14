defmodule PicopadProxy.AmiiboFile do
  alias AmiiboSerialization.Amiibo
  alias PicopadProxy.Errors

  @sizes [540, 2048]

  def parse(binary) when byte_size(binary) in @sizes do
    with {:ok, decrypted} <- decrypt(binary) do
      build(decrypted)
    end
  end

  def parse(_binary), do: {:error, :unsupported_size}

  def encrypt(data) do
    {:ok, AmiiboSerialization.encrypt_binary!(data)}
  rescue
    _error -> {:error, :encryption_failed}
  end

  def message(:unsupported_size) do
    "Unsupported file size: expected a 540 byte (v2) or 2048 byte (v3) amiibo dump"
  end

  def message(:decryption_failed), do: "Could not decrypt the amiibo (wrong key or damaged file)"
  def message(:invalid_amiibo), do: "Not a valid amiibo dump"
  def message(:encryption_failed), do: "Could not encrypt the amiibo for the device"
  def message({:save_failed, errors}), do: "Could not save the amiibo: #{inspect(errors)}"
  def message(reason), do: Errors.message(reason)

  defp decrypt(binary) do
    if AmiiboSerialization.encrypted?(binary) do
      case AmiiboSerialization.decrypt_binary(binary) do
        {:ok, decrypted} -> {:ok, decrypted}
        _other -> {:error, :decryption_failed}
      end
    else
      {:ok, binary}
    end
  end

  defp build(decrypted) do
    {:ok, Amiibo.new(decrypted)}
  rescue
    _error -> {:error, :invalid_amiibo}
  end
end
