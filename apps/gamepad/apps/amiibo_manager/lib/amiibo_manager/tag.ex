defmodule AmiiboManager.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tags" do
    field(:slug, :string)
    field(:display_name, :string)

    many_to_many(:amiibo, AmiiboManager.Amiibo, join_through: "amiibo_tags", on_replace: :delete)

    timestamps()
  end

  @doc false
  def changeset(tag, attrs \\ %{}) do
    tag
    |> cast(attrs, [:slug, :display_name])
    |> validate_required([:slug, :display_name])
  end
end
