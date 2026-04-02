defmodule Bracket.Seeding.Rating do
  @moduledoc false

  @doc """
  Returns a seeding strategy that sorts participants by an arbitrary rating function.

  The rating function receives a `Bracket.Participant.t()` and returns a number.
  Higher values rank higher (seed 1).

  ## Example

      # Seed by a numeric score stored in metadata
      strategy = Bracket.Seeding.Rating.by(fn p -> p.metadata[:elo] end)
      Bracket.start(tournament, strategy)
  """
  @spec by((Bracket.Participant.t() -> number())) :: Bracket.Seeding.strategy()
  def by(rating_fn) when is_function(rating_fn, 1) do
    {:rating, rating_fn}
  end

  @doc """
  Returns a seeding strategy for TrueSkill `{mu, sigma}` ratings.

  Uses the conservative estimate `mu - 3 * sigma` as the sort key, which
  represents a lower bound on true skill with ~99.7% confidence.

  The rating is read from `participant.metadata[key]`, defaulting to `:rating`.

  ## Example

      # Participants with metadata: %{rating: {25.0, 8.33}}
      strategy = Bracket.Seeding.Rating.by_trueskill()
      Bracket.start(tournament, strategy)
  """
  @spec by_trueskill(atom()) :: Bracket.Seeding.strategy()
  def by_trueskill(key \\ :rating) do
    by(fn participant ->
      case Map.get(participant.metadata, key) do
        {mu, sigma} -> mu - 3 * sigma
        nil -> 0.0
        score when is_number(score) -> score
      end
    end)
  end
end
