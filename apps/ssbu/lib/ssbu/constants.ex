defmodule SSBU.Constants do
  defmacro ability_sources() do
    ["support spirit", "primary spirit", "unobtainable", "skill tree", "none", "unknown"]
  end

  defmacro legal_ability_sources() do
    ["support spirit"]
  end

  defmacro ability_categories() do
    [
      "common ban",
      "attack",
      "defense",
      "item",
      "recovery",
      "mobility",
      "special",
      "hazard",
      "other",
      "skill tree",
      "unknown",
      "cut",
      "none",
      "unused"
    ]
  end

  defmacro legal_ability_categories() do
    [
      "common ban",
      "attack",
      "defense",
      "item",
      "recovery",
      "mobility",
      "special",
      "hazard",
      "other"
    ]
  end

  defmacro spirit_types() do
    [
      "Neutral",
      "Sword",
      "Shield",
      "Grab"
    ]
  end
end
