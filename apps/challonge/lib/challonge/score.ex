defmodule Challonge.Score do
  defstruct [:sets]

  @type t() :: %__MODULE__{
          sets: [{integer(), integer()}]
        }

  def new() do
    %__MODULE__{sets: []}
  end

  def new(score1, score2) do
    %__MODULE__{sets: [{score1, score2}]}
  end

  defp new(sets) do
    %__MODULE__{sets: sets}
  end

  def add_set(score = %__MODULE__{}, score1, score2) do
    %__MODULE__{sets: [{score1, score2} | score.sets]}
  end

  def parse_csv("") do
    new()
  end

  def parse_csv(csv) do
    csv
    |> String.split(",")
    |> Enum.map(&String.split(&1, "-"))
    |> Enum.map(fn [x, y] -> {String.to_integer(x), String.to_integer(y)} end)
    |> Enum.reverse()
    |> new()
  end

  def to_csv(%__MODULE__{sets: sets}) do
    sets
    |> Enum.reverse()
    |> Enum.map(fn {x, y} -> "#{x}-#{y}" end)
    |> Enum.join(",")
  end

  def winner(%__MODULE__{sets: sets}) do
    p1_wins = Enum.count(sets, fn {x, y} -> x > y end)
    p2_wins = Enum.count(sets, fn {x, y} -> x < y end)

    cond do
      p1_wins > p2_wins ->
        :p1

      p1_wins < p2_wins ->
        :p2

      true ->
        :tie
    end
  end
end
