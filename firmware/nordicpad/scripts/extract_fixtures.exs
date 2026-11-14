Code.require_file("../../scripts/ble_decrypt_lib.exs", __DIR__)

defmodule ExtractFixtures do
  @command_handle 0x0016
  @reply_handle 0x001A
  @command_prefix_size 17
  @unkeyed "00000000000000000000000000000000"
  @memory_read_command 0x02
  @memory_read_subcommand 0x04
  @pairing_command 0x15
  @volatile_commands [@pairing_command]

  def main([pcap, fixtures_dir, generated_dir]) do
    link_key = derive_link_key(pcap)
    exchanges = pcap |> BleDecrypt.attribute_messages(link_key) |> exchanges()

    File.mkdir_p!(fixtures_dir)
    File.mkdir_p!(generated_dir)
    write_init_exchanges(exchanges, fixtures_dir)
    write_memory_regions(exchanges, fixtures_dir)
    write_identity_source(exchanges, generated_dir)
    IO.puts("link key derived from the pairing in #{pcap}, exchanges: #{length(exchanges)}")
  end

  defp derive_link_key(pcap) do
    messages = BleDecrypt.attribute_messages(pcap, @unkeyed)
    host_key = pairing_payload(messages, :request)
    controller_key = pairing_payload(messages, :reply)

    host_key
    |> :crypto.exor(controller_key)
    |> Base.encode16(case: :lower)
  end

  defp pairing_payload(messages, :request) do
    Enum.find_value(messages, &host_key/1) || raise "no pairing request (15/04) in the capture"
  end

  defp pairing_payload(messages, :reply) do
    Enum.find_value(messages, &controller_key/1) || raise "no pairing reply (15/04) in the capture"
  end

  defp host_key(%{master: true, handle: @command_handle, value: value}) do
    case strip_prefix(value) do
      <<0x15, 0x91, 0x01, 0x04, _::binary-size(4), 0x00, key::binary-size(16)>> -> key
      _other -> nil
    end
  end

  defp host_key(_message) do
    nil
  end

  defp controller_key(%{master: false, handle: @reply_handle, value: value}) do
    case value do
      <<0x15, 0x01, 0x01, 0x04, _::binary-size(4), 0x01, key::binary-size(16)>> -> key
      _other -> nil
    end
  end

  defp controller_key(_message) do
    nil
  end

  defp strip_prefix(value) when byte_size(value) > @command_prefix_size do
    binary_part(value, @command_prefix_size, byte_size(value) - @command_prefix_size)
  end

  defp strip_prefix(value) do
    value
  end

  defp exchanges(messages) do
    messages
    |> Enum.reduce(%{pending: %{}, done: []}, &collect/2)
    |> Map.fetch!(:done)
    |> Enum.reverse()
  end

  defp collect(%{master: true, handle: @command_handle} = message, state) do
    request = strip_prefix(message.value)
    key = {message.access_address, command_key(request)}
    put_in(state, [:pending, key], %{message: message, request: request})
  end

  defp collect(%{master: false, handle: @reply_handle} = message, state) do
    key = {message.access_address, command_key(message.value)}

    case Map.pop(state.pending, key) do
      {nil, _pending} ->
        state

      {request, pending} ->
        exchange = %{frame: request.message.frame, request: request.message.value, reply: message.value}
        %{state | pending: pending, done: [exchange | state.done]}
    end
  end

  defp collect(_message, state) do
    state
  end

  defp command_key(<<command, _direction, _transport, subcommand, _rest::binary>>) do
    {command, subcommand}
  end

  defp command_key(_other) do
    nil
  end

  defp write_init_exchanges(exchanges, output_dir) do
    pairs =
      exchanges
      |> Enum.reject(&volatile?/1)
      |> Enum.reject(&nfc?/1)
      |> Enum.map(&{Base.encode16(&1.request, case: :lower), Base.encode16(&1.reply, case: :lower)})
      |> Enum.uniq()

    conflicts = pairs |> Enum.group_by(&elem(&1, 0)) |> Enum.filter(fn {_request, replies} -> length(replies) > 1 end)
    Enum.each(conflicts, fn {request, _replies} -> IO.puts("warning: request with differing replies: #{request}") end)

    lines = Enum.map(pairs, fn {request, reply} -> "#{request} #{reply}\n" end)
    File.write!(Path.join(output_dir, "init_exchanges.txt"), lines)
    IO.puts("init exchanges written: #{length(pairs)}")
  end

  defp write_memory_regions(exchanges, output_dir) do
    regions =
      exchanges
      |> Enum.filter(&memory_read?/1)
      |> Enum.map(&memory_region/1)
      |> Enum.uniq()
      |> Enum.sort()

    lines = Enum.map(regions, fn {address, data} -> "#{address} #{Base.encode16(data, case: :lower)}\n" end)
    File.write!(Path.join(output_dir, "memory_regions.txt"), lines)
    IO.puts("memory regions written: #{length(regions)}")
  end

  defp write_identity_source(exchanges, generated_dir) do
    regions =
      exchanges
      |> Enum.filter(&memory_read?/1)
      |> Enum.map(&memory_region/1)
      |> Enum.uniq()
      |> Enum.sort()

    replies =
      exchanges
      |> Enum.reject(&volatile?/1)
      |> Enum.reject(&nfc?/1)
      |> Enum.reject(&memory_read?/1)
      |> Enum.map(&static_reply/1)
      |> Enum.uniq()
      |> Enum.sort()

    source = identity_source(regions, replies)
    File.write!(Path.join(generated_dir, "identity_data.c"), source)
    IO.puts("identity source written: #{length(regions)} regions, #{length(replies)} static replies")
  end

  defp static_reply(%{reply: <<command, _direction, _transport, subcommand, _tail::binary-size(4), payload::binary>>}) do
    {command, subcommand, payload}
  end

  defp identity_source(regions, replies) do
    region_arrays = regions |> Enum.with_index() |> Enum.map(fn {{_address, data}, index} -> byte_array("MEMORY_REGION_#{index}", data) end)
    reply_arrays = replies |> Enum.with_index() |> Enum.map(fn {{_command, _sub, payload}, index} -> byte_array("STATIC_REPLY_#{index}", payload) end)

    region_rows =
      regions
      |> Enum.with_index()
      |> Enum.map(fn {{address, data}, index} -> "    {0x#{hex32(address)}, #{byte_size(data)}, MEMORY_REGION_#{index}},\n" end)

    reply_rows =
      replies
      |> Enum.with_index()
      |> Enum.map(fn {{command, subcommand, payload}, index} ->
        "    {0x#{hex8(command)}, 0x#{hex8(subcommand)}, #{reply_data_name(payload, index)}, #{byte_size(payload)}},\n"
      end)

    [
      "#include \"controller/identity.h\"\n\n",
      region_arrays,
      reply_arrays,
      "static const memory_region_t MEMORY_REGIONS[] = {\n",
      region_rows,
      "};\n\nstatic const static_reply_t STATIC_REPLIES[] = {\n",
      reply_rows,
      "};\n\nconst controller_identity_t CONTROLLER_IDENTITY = {\n",
      "    .memory_regions = MEMORY_REGIONS,\n",
      "    .memory_region_count = #{length(regions)},\n",
      "    .static_replies = STATIC_REPLIES,\n",
      "    .static_reply_count = #{length(replies)},\n",
      "};\n"
    ]
  end

  defp reply_data_name(<<>>, _index) do
    "NULL"
  end

  defp reply_data_name(_payload, index) do
    "STATIC_REPLY_#{index}"
  end

  defp byte_array(_name, <<>>) do
    ""
  end

  defp byte_array(name, data) do
    rows =
      data
      |> :binary.bin_to_list()
      |> Enum.chunk_every(12)
      |> Enum.map(fn row -> "    " <> Enum.map_join(row, ", ", &"0x#{hex8(&1)}") <> ",\n" end)

    ["static const uint8_t ", name, "[] = {\n", rows, "};\n\n"]
  end

  defp hex8(value) do
    value |> Integer.to_string(16) |> String.pad_leading(2, "0")
  end

  defp hex32(value) do
    value |> Integer.to_string(16) |> String.pad_leading(8, "0")
  end

  defp memory_read?(%{reply: <<@memory_read_command, _::binary>>, request: request}) do
    match?(<<@memory_read_command, _, _, @memory_read_subcommand, _::binary>>, strip_prefix(request))
  end

  defp memory_read?(_exchange) do
    false
  end

  defp memory_region(%{reply: <<_command, _direction, _transport, _sub, _tail::binary-size(4), length, _pad::binary-size(3), address::little-32, data::binary>>}) do
    {address, binary_part(data, 0, min(length, byte_size(data)))}
  end

  defp volatile?(%{request: request}) do
    case strip_prefix(request) do
      <<command, _rest::binary>> -> command in @volatile_commands
      _other -> false
    end
  end

  defp nfc?(%{request: request}) do
    match?(<<0x01, _rest::binary>>, strip_prefix(request)) and not match?(<<0x01, 0x91, 0x01, 0x0C, _::binary>>, strip_prefix(request))
  end
end

ExtractFixtures.main(System.argv())
