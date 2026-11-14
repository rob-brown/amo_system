defmodule Picopad.Test.FakeFirmware do
  @chunk_size 128
  @status_unknown_command 0x01
  @status_invalid_params 0x02
  @status_amiibo_error 0x05

  @pico_only [0x04, 0x05, 0x35, 0x36, 0x38, 0x39, 0x3A, 0x42, 0xF3, 0xF4]
  @nordicpad_only [0x43]
  @accepted_with_empty_reply [
    0x02,
    0x03,
    0x04,
    0x05,
    0x10,
    0x11,
    0x12,
    0x13,
    0x14,
    0x20,
    0x38,
    0x40,
    0x41,
    0xF2,
    0xF3,
    0xF4
  ]

  def new(kind, opts \\ []) when kind in [:picopad, :nordicpad] do
    %{
      kind: kind,
      connection: Keyword.get(opts, :connection, 3),
      controller: Keyword.get(opts, :controller, 3),
      amiibo: Keyword.get(opts, :amiibo, <<>>),
      upload: nil
    }
  end

  def version_string(:picopad), do: "1.0.0"
  def version_string(:nordicpad), do: "nordicpad 0.1.0"

  def chunk_size, do: @chunk_size

  def handle(state, cmd, payload) do
    if supported?(state.kind, cmd) do
      respond(state, cmd, payload)
    else
      {{:status, @status_unknown_command}, state}
    end
  end

  defp supported?(:picopad, cmd), do: cmd not in @nordicpad_only
  defp supported?(:nordicpad, cmd), do: cmd not in @pico_only

  defp respond(state, 0x01, _payload) do
    amiibo_flag = if state.amiibo == <<>>, do: 0, else: 1
    reply = <<state.connection, state.controller, 0xFF, amiibo_flag, 0, 0, 0, 0, 0, 0>>
    {{:ok, reply}, state}
  end

  defp respond(state, cmd, _payload) when cmd in @accepted_with_empty_reply do
    {{:ok, <<>>}, state}
  end

  defp respond(state, 0x15, _payload) do
    {{:ok, <<0::size(88)>>}, state}
  end

  defp respond(state, 0x30, _payload) do
    {{:ok, amiibo_status(state.amiibo)}, state}
  end

  defp respond(state, 0x32, <<size::little-16>>) do
    {{:ok, <<@chunk_size>>}, %{state | upload: %{size: size, chunks: %{}}}}
  end

  defp respond(state, 0x33, <<index, data::binary>>) do
    upload = %{state.upload | chunks: Map.put(state.upload.chunks, index, data)}
    {{:ok, <<>>}, %{state | upload: upload}}
  end

  defp respond(state, 0x34, _payload) do
    dump =
      state.upload.chunks
      |> Enum.sort()
      |> Enum.map_join(fn {_index, data} -> data end)

    {{:ok, binary_part(dump, 0, 7)}, %{state | amiibo: dump, upload: nil}}
  end

  defp respond(%{amiibo: <<>>} = state, cmd, _payload) when cmd in [0x35, 0x36] do
    {{:status, @status_amiibo_error}, state}
  end

  defp respond(state, 0x35, _payload) do
    {{:ok, <<byte_size(state.amiibo)::little-16, @chunk_size>>}, state}
  end

  defp respond(state, 0x36, <<index>>) do
    offset = index * @chunk_size

    if offset < byte_size(state.amiibo) do
      length = min(@chunk_size, byte_size(state.amiibo) - offset)
      {{:ok, binary_part(state.amiibo, offset, length)}, state}
    else
      {{:status, @status_invalid_params}, state}
    end
  end

  defp respond(state, 0x37, _payload) do
    {{:ok, <<>>}, %{state | amiibo: <<>>}}
  end

  defp respond(state, 0x39, _payload) do
    {{:ok, <<1, 1, 0x30, 0>>}, state}
  end

  defp respond(state, 0x3A, _payload) do
    {{:ok, <<0::size(320)>>}, state}
  end

  defp respond(state, 0x42, _payload) do
    {{:ok, <<1, 1, 2, 3, 4, 5, 6, 0::32, 7::16>>}, state}
  end

  defp respond(state, 0x43, payload) when byte_size(payload) == 12 do
    {{:ok, <<>>}, state}
  end

  defp respond(state, 0x43, _payload) do
    {{:status, @status_invalid_params}, state}
  end

  defp respond(state, 0xF0, payload) do
    {{:ok, payload}, state}
  end

  defp respond(state, 0xF1, _payload) do
    {{:ok, <<0, 1, 0, version_string(state.kind)::binary, 0>>}, state}
  end

  defp respond(state, _cmd, _payload) do
    {{:status, @status_unknown_command}, state}
  end

  defp amiibo_status(<<>>), do: <<0, 0::size(56), 0::little-16>>

  defp amiibo_status(dump) do
    <<1, binary_part(dump, 0, 7)::binary, byte_size(dump)::little-16>>
  end
end
