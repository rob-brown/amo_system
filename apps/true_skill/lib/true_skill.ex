defmodule TrueSkill do
  @moduledoc """
  A minimal TrueSkill 1-vs-1 rating update. Ignores draw probability.
  """

  @type mu() :: float()
  @type sigma() :: float()
  @type rating() :: {mu(), sigma()}

  @default_mu 25.0
  @default_sigma @default_mu / 3.0
  @default_beta @default_sigma / 2.0
  @default_tau @default_sigma / 100.0

  @doc """
  Returns a new rating tuple with the default values.
  """
  @spec default_rating() :: rating()
  def default_rating() do
    {@default_mu, @default_sigma}
  end

  @doc """
  If the third parameter is `:p1` or `:p2`, calculates the winner accordingly. 
  Otherwise, the third parameter is an option list and assumes the winner is `:p1`. 
  """
  def update_1v1(p1_rating, p2_rating, opts \\ [])

  @spec update_1v1(rating(), rating(), Keyword.t()) :: {rating(), rating()}
  def update_1v1({p1_mu, p1_sigma}, {p2_mu, p2_sigma}, opts) when is_list(opts) do
    {tau, opts} = Keyword.pop(opts, :tau, @default_tau)
    {beta, opts} = Keyword.pop(opts, :beta, @default_beta)

    if opts != [] do
      raise "Unknown options #{inspect(Keyword.keys(opts))}"
    end

    # Inflates sigma with the dynamic factor, tau
    p1_sigma_sq = p1_sigma * p1_sigma + tau * tau
    p2_sigma_sq = p2_sigma * p2_sigma + tau * tau

    # Now does the standard TrueSkill 1v1 update
    c = :math.sqrt(p1_sigma_sq + p2_sigma_sq + 2.0 * beta * beta)

    delta_mu = p1_mu - p2_mu
    t = delta_mu / c

    v = v_func(t)
    w = w_func(t)

    p1_mu_new = p1_mu + p1_sigma_sq / c * v
    p2_mu_new = p2_mu - p2_sigma_sq / c * v

    p1_sigma_sq_new = p1_sigma_sq * (1.0 - p1_sigma_sq / (c * c) * w)
    p2_sigma_sq_new = p2_sigma_sq * (1.0 - p2_sigma_sq / (c * c) * w)

    {{p1_mu_new, :math.sqrt(p1_sigma_sq_new)}, {p2_mu_new, :math.sqrt(p2_sigma_sq_new)}}
  end

  @spec update_1v1(rating(), rating(), :p1 | :p2) :: {rating(), rating()}
  def update_1v1(p1_rating, p2_rating, winner) when winner in [:p1, :p2] do
    update_1v1(p1_rating, p2_rating, winner, [])
  end

  @doc """
  Updates the ratings for two players in a 1-vs-1 match.

  Each rating is a tuple: `{mu, sigma}`.

  `winner` must be either `:p1` or `:p2`.

  `opts` may contain keys `:beta` or `:tau`. Raises if any other parameters given.

  Returns a tuple: `{{p1_mu_new, p1_sigma_new}, {p2_mu_new, p2_sigma_new}}`.

      iex> TrueSkill.update_1v1(TrueSkill.default_rating, TrueSkill.default_rating)
      {{29.205473176557785, 7.194816484813345}, {20.794526823442215, 7.194816484813345}}

      iex> TrueSkill.update_1v1({28.2, 6.5}, {27.5, 3.0})
      {{31.619867334646433, 5.420792569786221}, {26.77106525340404, 2.9020940778843007}}

      iex> TrueSkill.update_1v1(TrueSkill.default_rating, TrueSkill.default_rating, beta: 3, tau: 1)
      {{29.459026423452684, 7.110662964829316}, {20.540973576547316, 7.110662964829316}}
  """
  @spec update_1v1(rating(), rating(), :p1 | :p2, Keyword.t()) :: {rating(), rating()}
  def update_1v1(p1_rating, p2_rating, winner, opts)

  def update_1v1(p1_rating, p2_rating, :p1, opts) do
    update_1v1(p1_rating, p2_rating, opts)
  end

  def update_1v1(p1_rating, p2_rating, :p2, opts) do
    # Flips the order of the players and calls update_1v1/3.
    {new_p2_rating, new_p1_rating} = update_1v1(p2_rating, p1_rating, opts)

    # Flips the ratings back in the right order.
    {new_p1_rating, new_p2_rating}
  end

  ## Helpers

  # Standard normal PDF
  defp pdf(x) do
    1.0 / :math.sqrt(2.0 * :math.pi()) * :math.exp(-0.5 * x * x)
  end

  # Standard normal CDF using :math.erf/1 (OTP 24+)
  defp cdf(x) do
    0.5 * (1.0 + :math.erf(x / :math.sqrt(2.0)))
  end

  # V(t) function as per TrueSkill derivation
  defp v_func(t), do: pdf(t) / cdf(t)

  # W(t) function
  defp w_func(t) do
    v = v_func(t)
    v * (v + t)
  end
end
