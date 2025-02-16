defmodule SSBU.Ability do
  require SSBU.Constants, as: Constants

  @ability_file Path.join(__DIR__, "../../ability.csv")
  @external_resource @ability_file
  @ability_map @ability_file
               |> File.read!()
               |> String.split("\n")
               |> Stream.reject(&match?("#" <> _, &1))
               |> Stream.reject(&(&1 == ""))
               |> Stream.map(&String.split(&1, ","))
               |> Stream.map(fn [name, slots, source, category]
                                when slots in ~w"0 1 2 3" and
                                       category in Constants.ability_categories() and
                                       source in Constants.ability_sources() ->
                 %{
                   name: name,
                   slots: String.to_integer(slots),
                   source: source,
                   category: category
                 }
               end)
               |> Stream.with_index()
               |> Stream.map(fn {x, n} -> {n, Map.put(x, :value, n)} end)
               |> Map.new()

  @ability_names @ability_map
                 |> Map.values()
                 |> Stream.reject(&(&1.category == "unused"))
                 |> Stream.map(& &1.name)
                 |> MapSet.new()

  def abilities() do
    @ability_map
    |> Enum.sort()
    |> Keyword.values()
  end

  def ability_names() do
    @ability_names
  end

  def legal_abilities() do
    abilities()
    |> Stream.filter(&(&1.category in Constants.legal_ability_categories()))
    |> Stream.filter(&(&1.source in Constants.legal_ability_sources()))
    |> Enum.to_list()
  end

  def by_category(category) do
    legal_abilities()
    |> Stream.filter(&match?(%{category: ^category}, &1))
    |> Enum.sort_by(& &1.name)
  end

  def from_value(nil) do
    nil
  end

  def from_value(value) do
    abilities()
    |> Stream.filter(&(&1.value == value))
    |> Enum.at(0)
  end

  def ability(value) when is_integer(value) do
    Map.get(@ability_map, value)
  end

  def null() do
    %{name: "None", slots: 0, source: "none", category: "none", value: 0}
  end
end
