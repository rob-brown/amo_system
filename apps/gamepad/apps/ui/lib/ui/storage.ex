defmodule Ui.Storage do
  @moduledoc """
  The Storage context.
  """

  import Ecto.Query, warn: false

  @doc """
  Returns the list of collections.

  ## Examples

      iex> list_collections()
      [%Collection{}, ...]

  """
  defdelegate list_collections, to: AmiiboManager

  @doc """
  Gets a single collection.

  Raises `Ecto.NoResultsError` if the Collection does not exist.

  ## Examples

      iex> get_collection("aRBT")
      %Collection{}

      iex> get_collection!("Vanilla")
      ** (Ecto.NoResultsError)

  """
  defdelegate get_collection(name), to: AmiiboManager

  defdelegate get_collection!(id), to: AmiiboManager

  @doc """
  Creates a collection.

  ## Examples

      iex> create_collection("Squad Strike Bravo")
      {:ok, %Collection{}}
  """
  defdelegate create_collection(name), to: AmiiboManager

  defdelegate delete_collection(id), to: AmiiboManager

  defdelegate get_amiibo(id), to: AmiiboManager

  defdelegate list_amiibo(name), to: AmiiboManager

  defdelegate search(collection_name, query), to: AmiiboManager

  defdelegate list_tags(), to: AmiiboManager
end
