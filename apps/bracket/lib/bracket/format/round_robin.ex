defmodule Bracket.Format.RoundRobin do
  @moduledoc false

  @behaviour Bracket.Format

  @impl true
  def generate_matches(_tournament) do
    {:error, :not_implemented}
  end

  @impl true
  def standings(_tournament) do
    []
  end

  @impl true
  def complete?(_tournament) do
    false
  end
end
