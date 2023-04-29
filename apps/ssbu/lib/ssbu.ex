defmodule SSBU do

  import Bitwise

  alias AmiiboSerialization.Amiibo
  alias AmiiboSerialization.ByteBuffer
  alias SSBU.Ability
  alias SSBU.Character

  @ssbu_app_id 0x34F80200

  def ssbu_registered?(amiibo) do
    Amiibo.app_id(amiibo) == @ssbu_app_id
  end

  def abilities(amiibo) do
    <<a1, a2, a3>> = Amiibo.bytes(amiibo, 236..238)

    [a1, a2, a3]
    |> Enum.reject(&(&1 == 0))
    |> Enum.map(&Ability.ability/1)
  end

  def type(amiibo) do
    <<type>> = Amiibo.bytes(amiibo, 227..227)

    case type >>> 6 do
      0 -> "Neutral"
      1 -> "Sword"
      2 -> "Shield"
      3 -> "Grab"
    end
  end

  def learning?(%Amiibo{binary: <<_::binary-size(226), learning, _::bits>>}) do
    (learning &&& 0x01) > 0
  end

  def disable_learning(a = %Amiibo{binary: <<first::binary-size(226), _, rest::bits>>}) do
    %Amiibo{a | binary: <<first::binary, 0, rest::binary>>}
  end

  def vanilla?(%Amiibo{binary: binary}) do
    <<
      _::binary-size(236),
      ability1,
      ability2,
      ability3,
      _::binary-size(97),
      attack::signed-little-size(16),
      defense::signed-little-size(16),
      _::bits
    >> = binary

    # I could check type too but it doesn't change much in battle.

    ability1 == 0 and ability2 == 0 and ability3 == 0 and attack == 0 and defense == 0
  end

  def spirit?(amiibo) do
    not vanilla?(amiibo)
  end

  def stats(%Amiibo{binary: binary}) do
    <<_::binary-size(336), attack::signed-little-size(16), defense::signed-little-size(16),
      _::bits>> = binary

    {attack, defense}
  end

  def set_voice(%Amiibo{binary: binary}, voice) when voice in 0..7 do
    binary
    |> ByteBuffer.from_binary()
    |> ByteBuffer.set(418, <<voice>>)
    |> ByteBuffer.to_binary()
    |> Amiibo.new()
  end

  def set_costume(%Amiibo{binary: binary}, costume) when costume in 0..7 do
    binary
    |> ByteBuffer.from_binary()
    |> ByteBuffer.set(419, <<costume>>)
    |> ByteBuffer.to_binary()
    |> Amiibo.new()
  end

  def max_level(%Amiibo{binary: binary}) do
    binary
    |> ByteBuffer.from_binary()
    # Amiibo Level
    |> ByteBuffer.set(332, <<3912::unsigned-little-size(16)>>)
    # CPU Level
    |> ByteBuffer.set(334, <<2765::unsigned-little-size(16)>>)
    |> ByteBuffer.to_binary()
    |> Amiibo.new()
  end

  def character(amiibo) do
    {character, variation} = character_info(amiibo)
    Character.lookup(character, variation).name
  end

  def character_info(%Amiibo{binary: binary}) do
    <<_::binary-size(476), character::unsigned-big-size(32), variation::unsigned-big-size(32),
      _::bits>> = binary

    {format_hex(character), format_hex(variation)}
  end

  def training_data(amiibo) do
    Amiibo.bytes(amiibo, 360..417)
  end

  def set_training_data(%Amiibo{binary: binary}, <<training_data::binary-size(58)>>) do
    binary
    |> ByteBuffer.from_binary()
    |> ByteBuffer.set(360, training_data)
    |> ByteBuffer.to_binary()
    |> Amiibo.new()
  end

  def set_character(%Amiibo{binary: binary}, character_id)
      when is_binary(character_id) and byte_size(character_id) == 8 do
    binary
    |> ByteBuffer.from_binary()
    |> ByteBuffer.set(476, character_id)
    |> ByteBuffer.to_binary()
    |> Amiibo.new()
  end

  def level(amiibo) do
    <<level::unsigned-little-size(16)>> = Amiibo.bytes(amiibo, 332..333)

    cond do
      level >= 3912 -> 50
      level >= 3669 -> 49
      level >= 3429 -> 48
      level >= 3209 -> 47
      level >= 2999 -> 46
      level >= 2799 -> 45
      level >= 2619 -> 44
      level >= 2459 -> 43
      level >= 2329 -> 42
      level >= 2220 -> 41
      level >= 2115 -> 40
      level >= 2012 -> 39
      level >= 1910 -> 38
      level >= 1816 -> 37
      level >= 1724 -> 36
      level >= 1637 -> 35
      level >= 1555 -> 34
      level >= 1478 -> 33
      level >= 1406 -> 32
      level >= 1339 -> 31
      level >= 1277 -> 30
      level >= 1222 -> 29
      level >= 1167 -> 28
      level >= 1112 -> 27
      level >= 1058 -> 26
      level >= 1004 -> 25
      level >= 950 -> 24
      level >= 896 -> 23
      level >= 843 -> 22
      level >= 790 -> 21
      level >= 737 -> 20
      level >= 684 -> 19
      level >= 632 -> 18
      level >= 580 -> 17
      level >= 528 -> 16
      level >= 476 -> 15
      level >= 426 -> 14
      level >= 376 -> 13
      level >= 330 -> 12
      level >= 284 -> 11
      level >= 238 -> 10
      level >= 195 -> 9
      level >= 155 -> 8
      level >= 120 -> 7
      level >= 90 -> 6
      level >= 63 -> 5
      level >= 41 -> 4
      level >= 22 -> 3
      level >= 8 -> 2
      true -> 1
    end
  end

  ## Helpers
  
  defp format_hex(string) do
    string
    |> Integer.to_string(16)
    |> String.downcase()
    |> String.pad_leading(8, "0")
  end
end
