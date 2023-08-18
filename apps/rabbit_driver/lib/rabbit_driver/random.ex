defmodule RabbitDriver.Random do
  @alphabet [?a..?z, ?A..?Z, ?0..?9] |> Enum.flat_map(& &1) |> Enum.map(&<<&1>>)

  def string(length \\ 8) do
    Stream.repeatedly(fn -> Enum.random(@alphabet) end)
    |> Enum.take(length)
    |> Enum.join()
  end
end
