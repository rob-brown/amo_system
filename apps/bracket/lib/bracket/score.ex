defmodule Bracket.Score do
  @moduledoc false

  defstruct sets: []

  @type set() :: {non_neg_integer(), non_neg_integer()}
  @type t() :: %__MODULE__{sets: [set()]}

  @spec new() :: t()
  def new do
    %__MODULE__{sets: []}
  end

  @spec new(non_neg_integer(), non_neg_integer()) :: t()
  def new(p1, p2) do
    %__MODULE__{sets: [{p1, p2}]}
  end

  @spec add_set(t(), non_neg_integer(), non_neg_integer()) :: t()
  def add_set(%__MODULE__{sets: sets}, p1, p2) do
    %__MODULE__{sets: sets ++ [{p1, p2}]}
  end

  @spec p1_wins(t()) :: non_neg_integer()
  def p1_wins(%__MODULE__{sets: sets}) do
    Enum.count(sets, fn {x, y} -> x > y end)
  end

  @spec p2_wins(t()) :: non_neg_integer()
  def p2_wins(%__MODULE__{sets: sets}) do
    Enum.count(sets, fn {x, y} -> x < y end)
  end

  @spec winner(t()) :: :p1 | :p2 | :tie
  def winner(%__MODULE__{} = score) do
    p1 = p1_wins(score)
    p2 = p2_wins(score)

    cond do
      p1 > p2 -> :p1
      p1 < p2 -> :p2
      true -> :tie
    end
  end

  @spec complete?(t(), pos_integer()) :: boolean()
  def complete?(%__MODULE__{} = score, best_of) do
    needed = div(best_of, 2) + 1
    p1_wins(score) >= needed or p2_wins(score) >= needed
  end

  @spec from_csv(binary()) :: t()
  def from_csv("") do
    new()
  end

  def from_csv(csv) do
    sets =
      csv
      |> String.split(",")
      |> Enum.map(&String.split(&1, "-"))
      |> Enum.map(fn [x, y] -> {String.to_integer(x), String.to_integer(y)} end)

    %__MODULE__{sets: sets}
  end

  @spec to_csv(t()) :: binary()
  def to_csv(%__MODULE__{sets: sets}) do
    sets
    |> Enum.map(fn {x, y} -> "#{x}-#{y}" end)
    |> Enum.join(",")
  end
end
