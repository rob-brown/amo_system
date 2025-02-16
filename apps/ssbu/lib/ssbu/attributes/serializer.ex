defmodule SSBU.Attributes.Serializer do
  alias AmiiboSerialization.Amiibo
  alias SSBU.Attributes

  @doc """
  Attribute values based on Mide's research.
  """
  def params() do
    [
      {"Near", 7},
      {"Offensive", 7},
      {"Grounded", 7},
      {"Attack Out Cliff", 6},
      {"Dash", 7},
      {"Return To Cliff", 6},
      {"Air Offensive", 6},
      {"Cliffer", 6},
      {"Feint Master", 7},
      {"Feint Counter", 7},
      {"Feint Shooter", 7},
      {"Catcher", 7},
      {"100 Attacker", 6},
      {"100 Keeper", 6},
      {"Attack Cancel", 6},
      {"Smash Holder", 7},
      {"Dash Attacker", 7},
      {"Critical Hitter", 6},
      {"Meteor Master", 6},
      {"Shield Master", 7},
      {"Just Shield Master", 6},
      {"Shield Catch Master", 6},
      {"Item Collector", 5},
      {"Item Throw to Target", 5},
      {"Dragoon Collector", 4},
      {"Smash Ball Collector", 4},
      {"Hammer Collector", 4},
      {"Special Flagger", 4},
      {"Item Swinger", 5},
      {"Homerun Batter", 4},
      {"Club Swinger", 4},
      {"Death Swinger", 4},
      {"Item Shooter", 5},
      {"Carrier Broker", 5},
      {"Charger", 5},
      {"Appeal", 5},
      {"Fighter 1", 7},
      {"Fighter 2", 7},
      {"Fighter 3", 7},
      {"Fighter 4", 7},
      {"Fighter 5", 7},
      {"Advantageous Fighter", 7},
      {"Weaken Fighter", 7},
      {"Revenge", 7},
      {"Forward Tilt", 10},
      {"Up Tilt", 10},
      {"Down Tilt", 10},
      {"Forward Smash", 10},
      {"Up Smash", 10},
      {"Down Smash", 10},
      {"Neutral Special", 10},
      {"Side Special", 10},
      {"Up Special", 10},
      {"Down Special", 10},
      {"Forward Air", 9},
      {"Back Air", 9},
      {"Up Air", 9},
      {"Down Air", 9},
      {"Neutral Special Air", 9},
      {"Side Special Air", 9},
      {"Up Special Air", 9},
      {"Down Special Air", 9},
      {"Front Air Dodge", 8},
      {"Back Air Dodge", 8},
      {"Up Taunt", 7},
      {"Down Taunt", 7}
    ]
  end

  def string_to_key(string) do
    string
    |> String.downcase()
    |> String.replace(" ", "_")
    |> String.to_atom()
  end

  def key_to_string(key) do
    key
    |> Atom.to_string()
    |> String.split("_")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  def build_binary(attributes = %Attributes{}) do
    map = Map.from_struct(attributes)

    for {name, size} <- params() do
      float = Map.fetch!(map, string_to_key(name))
      value = float_to_value(float, size)

      {name, {value, size, float}}
    end
    |> build_binary()
  end

  def build_binary(raw_values) when is_list(raw_values) do
    for {_key, {value, size, _float}} <- raw_values do
      value_to_bit_list(value, size)
    end
    |> List.flatten()
    |> Enum.chunk_every(8)
    |> Enum.map(fn [a, b, c, d, e, f, g, h] ->
      # Flips the bit order
      <<h::1, g::1, f::1, e::1, d::1, c::1, b::1, a::1>>
    end)
    |> Enum.join("")
  end

  def parse_amiibo(%Amiibo{binary: binary}) do
    <<_::binary-size(360), training_data::bits>> = binary
    bit_parse(params(), binary_to_bit_list(training_data))
  end

  def parse_binary(binary) when byte_size(binary) == 58 do
    bit_parse(params(), binary_to_bit_list(binary))
  end

  def add_implicit_attributes(attributes) do
    grounded_moves = [
      "Forward Tilt",
      "Up Tilt",
      "Down Tilt",
      "Forward Smash",
      "Up Smash",
      "Down Smash",
      "Neutral Special",
      "Side Special",
      "Up Special",
      "Down Special"
    ]

    aerial_moves = [
      "Forward Air",
      "Back Air",
      "Up Air",
      "Down Air",
      "Neutral Special Air",
      "Side Special Air",
      "Up Special Air",
      "Down Special Air"
    ]

    dodges = [
      "Front Air Dodge",
      "Back Air Dodge"
    ]

    taunts = [
      "Up Taunt",
      "Down Taunt"
    ]

    targeting = [
      "Advantageous Fighter",
      "Weaken Fighter",
      "Revenge"
    ]

    jab = implicit_attribute(attributes, "Jab", grounded_moves)
    nair = implicit_attribute(attributes, "Neutral Air", aerial_moves)
    neutral_dodge = implicit_attribute(attributes, "Neutral Air Dodge", dodges)
    side_taunt = implicit_attribute(attributes, "Side Taunt", taunts)
    stage_enemy = implicit_attribute(attributes, "Stage Enemy", targeting)

    [jab, nair, neutral_dodge, side_taunt, stage_enemy | attributes]
  end

  defp implicit_attribute(attributes, name, other_names) do
    target_attributes = Enum.filter(attributes, fn {name, _} -> name in other_names end)

    {_name, {_value, bits, _percent}} = hd(target_attributes)

    for {_name, {value, _bits, _percent}} <- target_attributes do
      value
    end
    |> Enum.sum()
    |> then(&max(0, trunc(:math.pow(2, bits)) - &1))
    |> then(&{name, {&1, bits, to_float(&1, bits)}})
  end

  def floats_to_raw_values(floats) do
    floats
    |> Enum.zip(params())
    |> Enum.map(fn {float, {name, bits}} ->
      value = float_to_value(float, bits)
      {name, {value, bits, float}}
    end)
  end

  defp bit_parse(params, bits, result \\ [])

  defp bit_parse([], _, result) do
    Enum.reverse(result)
  end

  defp bit_parse([{key, size} | rest], bits, result) do
    value = bits |> Enum.take(size) |> bit_list_to_number()
    remaining_bits = Enum.drop(bits, size)
    entry = {key, {value, size, to_float(value, size)}}

    bit_parse(rest, remaining_bits, [entry | result])
  end

  defp bit_list_to_number(bits) do
    # Bit list is already backwards, making it easy to compute the value.
    for {1, n} <- Enum.with_index(bits) do
      trunc(:math.pow(2, n))
    end
    |> Enum.sum()
  end

  def float_to_value(float, size) when is_float(float) do
    max = :math.pow(2, size) - 1
    Float.round(max * float) |> trunc()
  end

  def value_to_bit_list(value, size) do
    for n <- 0..(size - 1) do
      mask = Bitwise.bsl(1, n)

      if Bitwise.band(value, mask) == mask do
        1
      else
        0
      end
    end
  end

  defp binary_to_bit_list(binary, result \\ [])

  defp binary_to_bit_list(<<>>, result) do
    # Bits are reversed back to original order but each bit in a byte is still reversed.
    # This is because the bits are read from the least significant bit first.
    Enum.reverse(result)
  end

  defp binary_to_bit_list(<<a::1, b::1, c::1, d::1, e::1, f::1, g::1, h::1, rest::bits>>, result) do
    # This ordering will cause each bit in a byte to be reversed.
    binary_to_bit_list(rest, [a, b, c, d, e, f, g, h | result])
  end

  defp to_float(value, bit_size) do
    value / (:math.pow(2, bit_size) - 1)
  end

  defp colors() do
    Stream.cycle([
      IO.ANSI.cyan(),
      IO.ANSI.green(),
      IO.ANSI.yellow(),
      IO.ANSI.magenta()
    ])
  end

  def print_bits(raw_values) do
    for {_key, {value, size, _float}} <- raw_values do
      value
      |> inspect(base: :binary)
      |> String.trim_leading("0b")
      |> String.pad_leading(size, "0")
      # Reverse each string since least significant bytes are read first.
      |> String.reverse()
    end
    |> Enum.zip(colors())
    |> Enum.flat_map(fn {string, color} ->
      string |> String.graphemes() |> Enum.map(&[color, &1, IO.ANSI.reset()])
    end)
    # Separate into bytes
    |> Enum.chunk_every(8)
    # Reverse each byte back to original order.
    |> Enum.map(&Enum.reverse/1)
    |> Enum.intersperse(" ")
    # Insert some lines
    |> Enum.chunk_every(12)
    |> Enum.intersperse("\n")
    |> IO.puts()
  end
end
