defmodule SSBU.Personality do
  alias AmiiboSerialization.Amiibo
  alias SSBU.Attributes
  alias SSBU.Personality.Branch

  @doc """
  Parses the attributes from the amiibo and returns the 
  personality name.
  """
  def parse_amiibo(amiibo = %Amiibo{}) do
    amiibo
    |> Attributes.parse()
    |> calculate_personality()
  end

  @doc """
  Returns the personality name given the set of attributes.
  """
  def calculate_personality(attributes = %Attributes{}) do
    scores = branch_scores(attributes)

    if scores == [] do
      "Normal"
    else
      {score, branch} = Enum.max(scores)

      # Pick the highest-scored personality, or Normal if none are high enough.
      branch.tiers
      |> Enum.filter(&(score >= &1.target_score))
      |> Enum.max_by(& &1.target_score, fn -> %{personality: "Normal"} end)
      |> then(& &1.personality)
    end
  end

  @doc """
  Returns the raw scores for each personality branch given the 
  set of attributes.
  """
  def branch_scores(attributes = %Attributes{}) do
    for branch <- Branch.data(), has_required_param?(branch, attributes) do
      score = branch_score(branch, attributes)
      {score, branch}
    end
  end

  ## Helpers

  defp has_required_param?(branch, attributes) do
    # Only one parameter is required, if any.
    requirement = Enum.find(branch.criteria, & &1.required)

    if requirement do
      attribute = Map.get(attributes, requirement.param_name)
      value = scale_value(attribute, requirement)

      value >= requirement.rank1.threshold
    else
      true
    end
  end

  defp scale_value(_value, %{param_name: :appeal}) do
    # The original code actually defines a default of 0 for 
    # "appeal" (taunting), and then divides it by 0. On ARM 
    # this just results in 0, anywhere else it'll blow up. ;)
    # This constant just happens to be right *most* of the time.
    0.25
  end

  defp scale_value(value, criterion) when is_number(value) do
    default = 50
    value = value * 100

    scaled =
      if criterion.desirable do
        (value - default) / default
      else
        (default - value) / default
      end

    clamp(scaled, 0..1)
  end

  defp branch_score(branch, attributes) do
    branch.criteria
    |> Enum.map(&criterion_score(&1, attributes))
    |> Enum.sum()
  end

  defp criterion_score(criterion, attributes) do
    value =
      attributes
      |> Map.get(criterion.param_name)
      |> scale_value(criterion)

    cond do
      value >= criterion.rank2.threshold ->
        criterion.rank1.points + criterion.rank2.points

      value >= criterion.rank1.threshold ->
        criterion.rank1.points

      true ->
        0
    end
  end

  defp clamp(value, lo..hi) do
    max(lo, min(hi, value))
  end
end
