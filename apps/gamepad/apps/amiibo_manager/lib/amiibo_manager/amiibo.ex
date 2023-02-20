defmodule AmiiboManager.Amiibo do
  use Ecto.Schema
  import Ecto.Changeset

  schema "amiibos" do
    field(:name, :string)
    field(:character, :string)
    field(:data, :binary)
    field(:amiibo_id, :string)

    belongs_to(:collection, AmiiboManager.Collection)
    many_to_many(:tags, AmiiboManager.Tag, join_through: "amiibo_tags", on_replace: :delete)

    timestamps()
  end

  @doc false
  def changeset(amiibo, attrs) do
    amiibo
    |> cast(attrs, [:name, :character, :data, :amiibo_id])
    |> validate_required([:name, :character, :data, :amiibo_id])
  end
end
