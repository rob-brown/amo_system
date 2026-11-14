defmodule KAR.Fixtures do
  alias AmiiboSerialization.Amiibo
  alias AmiiboSerialization.AppID

  def v3_amiibo(opts \\ []) do
    app_id = Keyword.get(opts, :app_id, AppID.kar())
    uid = Keyword.get(opts, :uid, <<0x04, 1, 2, 3, 4, 5, 6>>)
    sram = Keyword.get(opts, :sram, :binary.copy(<<0xEE>>, 64))
    filler = :binary.copy(<<0x11>>, 2048)

    <<head::binary-size(182), _::binary-size(4), mid::binary-size(282), _::binary-size(7),
      rest::binary-size(485), _::binary-size(64), tail::binary>> = filler

    <<head::binary, app_id::unsigned-big-size(32), mid::binary, uid::binary, rest::binary,
      sram::binary, tail::binary>>
    |> Amiibo.new()
  end

  def key_path, do: System.fetch_env!("AMIIBO_KEY_PATH")

  def dump(name) do
    "AMIIBO_V3_DUMP_DIR" |> System.fetch_env!() |> Path.join(name <> ".bin") |> File.read!()
  end

  def decrypted(name) do
    {:ok, binary} = AmiiboSerialization.decrypt_binary(dump(name), key_path())
    Amiibo.new(binary)
  end

  def encrypt!(%Amiibo{binary: binary}) do
    {:ok, encrypted} = AmiiboSerialization.encrypt_binary(binary, key_path())
    encrypted
  end
end
