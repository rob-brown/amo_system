defmodule AmiiboManager do
  alias AmiiboManager.Amiibo
  alias AmiiboManager.Tag
  alias AmiiboManager.Collection
  alias AmiiboManager.Repo

  import Ecto.Query

  defdelegate search(collection, query), to: AmiiboManager.Search

  def list_collections() do
    Repo.all(Collection) |> Repo.preload([:amiibo])
  end

  def create_collection(name) do
    %Collection{}
    |> Collection.changeset(%{name: name})
    |> Repo.insert()
  end

  def get_collection!(id) when is_integer(id) do
    Repo.get!(Collection, id)
  end

  def get_collection(name) when is_binary(name) do
    query = from(c in Collection, where: c.name == ^name, preload: [amiibo: :tags])

    Repo.one(query)
  end

  def delete_collection(id) when is_integer(id) do
    id |> get_collection!() |> Repo.delete()
  end

  def list_amiibo(collection_name) when is_binary(collection_name) do
    collection_name |> get_collection() |> then(& &1.amiibo)
  end

  def get_amiibo(id) when is_integer(id) do
    Amiibo |> Repo.get(id) |> Repo.preload(:tags)
  end

  def add_amiibo(collection_name, amiibo) when is_binary(collection_name) do
    collection_name
    |> get_collection()
    |> add_amiibo(amiibo)
  end

  def add_amiibo(collection = %Collection{}, amiibo) do
    {:ok, amiibo} = create_amiibo(amiibo)

    amiibo
    |> Repo.preload(:collection)
    |> Amiibo.changeset(%{})
    |> Ecto.Changeset.put_assoc(:collection, collection)
    |> Repo.update()
  end

  def create_amiibo(a = %AmiiboMod.Amiibo{}) do
    create_amiibo(%{
      name: AmiiboMod.Amiibo.nickname(a),
      character: AmiiboMod.Amiibo.character(a) || "unknown",
      data: a.binary,
      amiibo_id: Base.encode64(AmiiboMod.Amiibo.amiibo_id(a))
    })
  end

  def create_amiibo(amiibo = %Amiibo{}) do
    {:ok, amiibo}
  end

  def create_amiibo(attrs) do
    %Amiibo{}
    |> Amiibo.changeset(attrs)
    |> Repo.insert()
  end

  def tag_amiibo(amiibo = %Amiibo{}, tag_name) when is_binary(tag_name) do
    {:ok, tag} = upsert_tag(tag_name)
    amiibo = Repo.preload(amiibo, :tags)

    if tag in amiibo.tags do
      {:ok, amiibo}
    else
      amiibo
      |> Amiibo.changeset(%{})
      |> Ecto.Changeset.put_assoc(:tags, [tag | amiibo.tags])
      |> Repo.update()
    end
  end

  def untag_amiibo(amiibo = %Amiibo{}, tag_name) when is_binary(tag_name) do
    {:ok, tag} = upsert_tag(tag_name)
    amiibo = Repo.preload(amiibo, :tags)

    if tag in amiibo.tags do
      new_tags = Enum.reject(amiibo.tags, &(&1 == tag))

      amiibo
      |> Repo.preload(:tags)
      |> Amiibo.changeset(%{})
      |> Ecto.Changeset.put_assoc(:tags, new_tags)
      |> Repo.update()
    else
      {:ok, amiibo}
    end
  end

  def delete_amiibo(id) when is_integer(id) do
    id |> get_amiibo() |> Repo.delete()
  end

  def list_tags() do
    Repo.all(from(t in Tag, order_by: t.slug)) |> Repo.preload([:amiibo])
  end

  def get_tag!(id) do
    Repo.get!(Tag, id)
  end

  def get_tag(tag_name) when is_binary(tag_name) do
    slug = Slug.slugify(tag_name)
    query = from(t in Tag, where: t.slug == ^slug)

    Repo.one(query)
  end

  def upsert_tag(tag_name) when is_binary(tag_name) do
    slug = Slug.slugify(tag_name)

    case get_tag(slug) do
      nil ->
        %Tag{}
        |> Tag.changeset(%{slug: slug, display_name: tag_name})
        |> Repo.insert()

      tag ->
        {:ok, tag}
    end
  end

  def update_tag(tag, params) do
    tag
    |> Tag.changeset(params)
    |> Repo.update()
  end

  def delete_tag(id) do
    id |> get_tag!() |> Repo.delete()
  end
end
