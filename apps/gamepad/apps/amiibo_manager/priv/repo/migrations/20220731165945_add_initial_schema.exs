defmodule AmiiboManager.Repo.Migrations.AddInitialSchema do
  use Ecto.Migration

  def change do
    create table(:amiibos) do
      add(:name, :string)
      add(:character, :string)
      add(:data, :binary)
      add(:amiibo_id, :string)
      add(:collection_id, references(:collections, on_delete: :delete_all))

      timestamps()
    end

    create table(:collections) do
      add(:name, :string)

      timestamps()
    end

    create table(:tags) do
      add(:slug, :string)
      add(:display_name, :string)

      timestamps()
    end

    create table(:amiibo_tags) do
      add(:amiibo_id, references(:amiibos, on_delete: :nilify_all))
      add(:tag_id, references(:tags, on_delete: :nilify_all))
    end

    create(unique_index(:collections, [:name]))
    create(unique_index(:tags, [:slug]))
    create(unique_index(:amiibo_tags, [:amiibo_id, :tag_id]))
  end
end
