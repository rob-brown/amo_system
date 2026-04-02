defmodule Bracket.Seeding do
  @moduledoc false

  alias Bracket.{Participant, Tournament}

  @type strategy() :: :standard | :random | {:rating, (Participant.t() -> number())}

  @spec apply(Tournament.t(), strategy()) :: Tournament.t()
  def apply(%Tournament{} = tournament, strategy) do
    seeded = seed_participants(tournament.participants, strategy)

    participants =
      seeded
      |> Enum.with_index(1)
      |> Enum.map(fn {p, i} -> %{p | seed: i} end)

    seeding = Enum.map(participants, & &1.id)

    %{tournament | participants: participants, seeding: seeding}
    |> Tournament.touch()
  end

  defp seed_participants(participants, :standard) do
    participants
  end

  defp seed_participants(participants, :random) do
    Enum.shuffle(participants)
  end

  defp seed_participants(participants, {:rating, rating_fn}) do
    Enum.sort_by(participants, rating_fn, :desc)
  end

  @doc """
  Computes the canonical bracket positions for a bracket of the given size.

  Returns a list of seed numbers in match order, so position 0 is the top
  of the bracket and position 2n-1 is the bottom. Seeds are placed so that
  if all higher seeds win, they meet in the latest possible round.

  ## Examples

      iex> Bracket.Seeding.bracket_positions(4)
      [1, 4, 3, 2]

      iex> Bracket.Seeding.bracket_positions(8)
      [1, 8, 5, 4, 3, 6, 7, 2]
  """
  @spec bracket_positions(pos_integer()) :: [pos_integer()]
  def bracket_positions(2), do: [1, 2]

  def bracket_positions(size) do
    do_positions([1, 2], 2, size)
  end

  defp do_positions(seeds, current, target) when current == target, do: seeds

  defp do_positions(seeds, current, target) do
    next_size = current * 2

    next =
      seeds
      |> Enum.chunk_every(2)
      |> Enum.flat_map(fn [a, b] ->
        [a, next_size + 1 - a, next_size + 1 - b, b]
      end)

    do_positions(next, next_size, target)
  end
end
