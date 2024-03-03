defmodule TournamentRunner.AmiiboTracker do
  use Agent

  @name __MODULE__

  def start_link(_) do
    Agent.start_link(fn -> MapSet.new() end, name: @name)
  end

  def seen?(name \\ @name, amiibo) do
    Agent.get(name, fn set -> amiibo in set end)
  end

  def insert(name \\ @name, amiibo) do
    Agent.update(name, fn set -> MapSet.put(set, amiibo) end)
  end

  def clear(name \\ @name) do
    Agent.update(name, fn _ -> MapSet.new() end)
  end
end
