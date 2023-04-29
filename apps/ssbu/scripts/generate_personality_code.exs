#!/usr/bin/env elixir

# Generates the code from a TOML file so :toml doesn't need to be a runtime dependency

Mix.install([
  {:toml, "~> 0.7.0"}
])

file = Path.expand("../personality.toml", __DIR__)
bin = File.read!(file)
{:ok, data} = Toml.decode(bin)

defmodule Converter do
  def atom_keys(map) when is_map(map) do
    for {k, v} <- map, into: %{} do
      if is_map(v) do
        {String.to_atom(k), atom_keys(v)}
      else
        {String.to_atom(k), v}
      end
    end
  end

  def convert_tiers(list_of_maps) do
    Enum.map(list_of_maps, &atom_keys/1)
  end

  def convert_criteria(list_of_maps) do
    for map <- list_of_maps do
      map
      |> atom_keys()
      |> Map.put_new(:required, false)
      |> Map.update(:param_name, nil, &String.to_atom/1)
    end
  end
end

template = """
defmodule SSBU.Personality.Branch do
  @moduledoc \"\"\"
  Generated from `personality.toml` by generate_personality_code.exs
  \"\"\"

  defstruct [:name, :criteria, :tiers]

  def data() do
    [
      <%= Enum.map_join(data, ",", fn {branch, attributes} -> %>
      %__MODULE__{
        name: "<%= branch %>", 
        tiers: <%= inspect(convert_tiers.(attributes["tiers"])) %>,
        criteria: <%= inspect(convert_criteria.(attributes["criteria"])) %> 
      }<% end) %>
    ]
  end
end
"""

output_path = Path.expand("../lib/ssbu/personality/branch.ex", __DIR__)

output =
  EEx.eval_string(template,
    data: data,
    convert_tiers: &Converter.convert_tiers/1,
    convert_criteria: &Converter.convert_criteria/1
  )

formatted = Code.format_string!(output)

File.write!(output_path, formatted)

