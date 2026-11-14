Code.require_file("../../scripts/ble_decrypt_lib.exs", __DIR__)

defmodule ExtractNfcFixture do
  @command_handle 0x0016
  @reply_handle 0x001A
  @nfc_command 0x01
  @read_subcommand 0x15
  @reply_header_size 8
  @buffer_header_size 60

  def main([pcap, key, from_frame, to_frame, output_dir]) do
    File.mkdir_p!(output_dir)

    exchanges =
      pcap
      |> BleDecrypt.attribute_messages(key)
      |> Enum.filter(&in_range?(&1, String.to_integer(from_frame), String.to_integer(to_frame)))
      |> pair_exchanges()

    write_exchanges(exchanges, Path.join(output_dir, "nfc_v2_scan.txt"))
    write_dump(exchanges, Path.join(output_dir, "nfc_v2_dump.bin"))
    IO.puts("exchanges: #{length(exchanges)}")
  end

  defp in_range?(message, from_frame, to_frame) do
    message.frame >= from_frame and message.frame <= to_frame
  end

  defp pair_exchanges(messages) do
    {exchanges, _pending} =
      Enum.reduce(messages, {[], nil}, fn message, {exchanges, pending} ->
        collect(message, exchanges, pending)
      end)

    Enum.reverse(exchanges)
  end

  defp collect(%{master: true, handle: @command_handle, value: value}, exchanges, _pending) do
    {exchanges, value}
  end

  defp collect(%{master: false, handle: @reply_handle, value: value}, exchanges, request) when request != nil do
    {add_exchange(exchanges, request, value), nil}
  end

  defp collect(_message, exchanges, pending) do
    {exchanges, pending}
  end

  defp add_exchange(exchanges, request, reply) do
    if nfc_request?(request) do
      [%{request: request, reply: reply} | exchanges]
    else
      exchanges
    end
  end

  defp nfc_request?(request) do
    match?(<<_prefix::binary-size(17), @nfc_command, _rest::binary>>, request)
  end

  defp write_exchanges(exchanges, path) do
    lines =
      Enum.map(exchanges, fn %{request: request, reply: reply} ->
        Base.encode16(request, case: :lower) <> " " <> Base.encode16(reply, case: :lower) <> "\n"
      end)

    File.write!(path, lines)
  end

  defp write_dump(exchanges, path) do
    buffer =
      exchanges
      |> Enum.filter(&read_exchange?/1)
      |> Enum.map(&read_data/1)
      |> IO.iodata_to_binary()

    <<_header::binary-size(@buffer_header_size), dump::binary>> = buffer
    File.write!(path, dump)
    IO.puts("dump bytes: #{byte_size(dump)}")
  end

  defp read_exchange?(%{request: <<_prefix::binary-size(17), @nfc_command, _direction, _transport, @read_subcommand, _rest::binary>>}) do
    true
  end

  defp read_exchange?(_exchange) do
    false
  end

  defp read_data(%{reply: <<_header::binary-size(@reply_header_size), _flag, length::little-16, data::binary>>}) do
    binary_part(data, 0, length)
  end
end

ExtractNfcFixture.main(System.argv())
