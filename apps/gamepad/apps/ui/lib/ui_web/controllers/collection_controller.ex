defmodule UiWeb.CollectionController do
  use UiWeb, :controller

  alias Ui.Storage

  def index(conn, _params) do
    collections = Storage.list_collections()
    render(conn, "index.html", collections: collections)
  end

  def create(conn, %{"name" => name}) do
    case Storage.create_collection(name) do
      {:ok, _collection} ->
        conn
        |> put_flash(:info, "Collection created successfully")
        |> redirect(to: Routes.collection_path(conn, :index))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to create collection")
        |> redirect(to: Routes.collection_path(conn, :index))
    end
  end

  def delete(conn, %{"id" => id}) do
    id = String.to_integer(id)

    case Storage.delete_collection(id) do
      {:ok, _collection} ->
        conn
        |> put_flash(:info, "Collection deleted successfully.")
        |> redirect(to: Routes.collection_path(conn, :index))

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "Failed to delete collection")
        |> redirect(to: Routes.collection_path(conn, :index))
    end
  end
end
