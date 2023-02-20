defmodule AmiiboManager.Collection do
  use Ecto.Schema
  import Ecto.Changeset

  schema "collections" do
    field(:name, :string)

    has_many(:amiibo, AmiiboManager.Amiibo)

    timestamps()
  end

  @doc false
  def changeset(collection, attrs) do
    collection
    |> cast(attrs, [:name])
    |> validate_required([:name])
  end
end
