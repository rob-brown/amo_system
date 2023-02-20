defmodule AmiiboManager.Search do
  alias AmiiboManager.Amiibo
  alias AmiiboManager.Collection
  alias AmiiboManager.Repo
  alias AmiiboManager.Tag

  import Ecto.Query

  def search(collection, query) when is_binary(collection) and is_binary(query) do
    query
    |> tokenize()
    |> build_query(collection)
    |> Repo.all()
  end

  ## Helpers

  defp tokenize(query) do
    query
    |> String.split(" ")
    |> Enum.map(&process_token/1)
  end

  @query_fields ~w"name character id tag"

  defp process_token(token) do
    case String.split(token, ":", parts: 2) do
      [field, value] when field in @query_fields ->
        {String.to_atom(field), value}

      _ ->
        {:name, token}
    end
  end

  defp build_query(tokens, collection) when is_list(tokens) and is_binary(collection) do
    query =
      from(a in Amiibo,
        join: c in Collection,
        on: [id: a.collection_id],
        where: c.name == ^collection,
        left_join: t in assoc(a, :tags),
        distinct: true,
        preload: [:tags]
      )

    build_query(tokens, query)
  end

  defp build_query([], query) do
    query
  end

  defp build_query([{:name, name} | rest], query) do
    pattern = "%#{name}%"
    query = where(query, [a], like(a.name, ^pattern))
    build_query(rest, query)
  end

  defp build_query([{:character, character} | rest], query) do
    pattern = "%#{character}%"
    query = where(query, [a], like(a.character, ^pattern))
    build_query(rest, query)
  end

  defp build_query([{:id, id} | rest], query) do
    pattern = "%#{id}%"
    query = where(query, [a], like(a.amiibo_id, ^pattern))
    build_query(rest, query)
  end

  defp build_query([{:tag, tag} | rest], query) do
    slug = Slug.slugify(tag)

    if slug in ["", nil] do
      build_query(rest, query)
    else
      pattern = "%#{slug}%"
      query = where(query, [a, c, t], like(t.slug, ^pattern))

      build_query(rest, query)
    end
  end
end
