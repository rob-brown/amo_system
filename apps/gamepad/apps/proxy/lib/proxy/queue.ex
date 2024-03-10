defmodule Proxy.Queue do
  @enforce_keys [:queue]
  defstruct [:queue]

  def new() do
    new(:queue.new())
  end

  defp new(q) do
    %__MODULE__{queue: q}
  end

  def push_front(q, item) do
    new(:queue.in_r(item, q.queue))
  end

  def push_back(q, item) do
    new(:queue.in(item, q.queue))
  end

  def pop_front(q) do
    case :queue.out(q.queue) do
      {{:value, item}, queue} ->
        {new(queue), item}

      {:empty, _queue} ->
        {q, :empty}
    end
  end

  def pop_back(q) do
    case :queue.out_r(q.queue) do
      {{:value, item}, q} ->
        {new(q), item}

      {:empty, q} ->
        {new(q), :empty}
    end
  end

  def empty?(q) do
    :queue.is_empty(q.queue)
  end
end

defimpl Enumerable, for: Proxy.Queue do
  def count(q) do
    {:ok, :queue.len(q.queue)}
  end

  def member?(q, item) do
    {:ok, :queue.member(item, q.queue)}
  end

  def reduce(q, acc, fun) do
    q.queue |> :queue.to_list() |> Enumerable.List.reduce(acc, fun)
  end

  def slice(_q) do
    {:error, __MODULE__}
  end
end

defimpl Collectable, for: Proxy.Queue do
  def into(q) do
    collector = fn
      acc, {:cont, elem} ->
        @for.push_back(acc, elem)

      acc, :done ->
        acc

      _acc, :halt ->
        :ok
    end

    {q, collector}
  end
end
