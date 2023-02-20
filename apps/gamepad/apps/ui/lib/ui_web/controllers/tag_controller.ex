defmodule UiWeb.TagController do
  use UiWeb, :controller

  alias AmiiboManager.Tag

  def index(conn, _params) do
    tags = AmiiboManager.list_tags()
    changeset = Tag.changeset(%Tag{})
    render(conn, "index.html", tags: tags, changeset: changeset)
  end

  def new(conn, _params) do
    changeset = Tag.changeset(%Tag{})
    render(conn, "new.html", changeset: changeset)
  end

  def create(conn, %{"tag" => %{"name" => name}}) do
    case AmiiboManager.upsert_tag(name) do
      {:ok, _tag} ->
        conn
        |> put_flash(:info, "Tag created successfully.")
        |> redirect(to: Routes.tag_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "new.html", changeset: changeset)
    end
  end

  def edit(conn, %{"id" => id}) do
    tag = AmiiboManager.get_tag!(id) |> IO.inspect(label: "tag")
    changeset = Tag.changeset(tag)
    render(conn, "edit.html", tag: tag, changeset: changeset)
  end

  def update(conn, %{"id" => id, "tag" => %{"name" => name}}) do
    tag = AmiiboManager.get_tag!(id)
    tag_params = %{"display_name" => name, "slug" => Slug.slugify(name)}

    case AmiiboManager.update_tag(tag, tag_params) do
      {:ok, _tag} ->
        conn
        |> put_flash(:info, "Tag '#{tag.display_name}' renamed to '#{name}'.")
        |> redirect(to: Routes.tag_path(conn, :index))

      {:error, %Ecto.Changeset{} = changeset} ->
        render(conn, "edit.html", tag: tag, changeset: changeset)
    end
  end

  def delete(conn, %{"id" => id}) do
    {:ok, tag} = AmiiboManager.delete_tag(id)

    conn
    |> put_flash(:info, "Tag '#{tag.display_name}' deleted successfully.")
    |> redirect(to: Routes.tag_path(conn, :index))
  end
end
