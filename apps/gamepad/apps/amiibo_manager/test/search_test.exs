defmodule SearchTest do
  use ExUnit.Case

  alias AmiiboManager.Search
  alias AmiiboManager.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.checkin(Repo) end)

    collection_name = "Searchable Collection"
    {:ok, collection} = AmiiboManager.create_collection(collection_name)

    amiibo_fixture(collection, %{name: "Fierce Dei", character: "Link"})
    amiibo_fixture(collection, %{name: "Dizzy", character: "Daisy"})
    amiibo_fixture(collection, %{name: "Kronk", character: "King K. Rool"})
    amiibo_fixture(collection, %{name: "Danger", character: "Pokémon Trainer"})
    amiibo_fixture(collection, %{name: "Herbizarre", character: "Pokémon Trainer"})
    amiibo_fixture(collection, %{name: "Toothless", character: "Ridley"})
    amiibo_fixture(collection, %{name: "Waxillium", character: "Mii Gunner"})
    amiibo_fixture(collection, %{name: "Arthur", character: "Mii Swordfighter"})
    amiibo_fixture(collection, %{name: "Raya", character: "Byleth"})

    [collection: collection]
  end

  test "search all collection", env do
    results = Search.search(env.collection.name, "")

    assert Enum.count(results) == 9
  end

  test "search name", env do
    results = Search.search(env.collection.name, "D")
    assert Enum.count(results) == 3
    results = Search.search(env.collection.name, "Bogus")
    assert Enum.count(results) == 0
  end

  test "search name predicate", env do
    results = Search.search(env.collection.name, "name:Herb")
    assert Enum.count(results) == 1
    results = Search.search(env.collection.name, "name:Bogus")
    assert Enum.count(results) == 0
  end

  test "search character", env do
    results = Search.search(env.collection.name, "character:Train")
    assert Enum.count(results) == 2
    results = Search.search(env.collection.name, "character:Mii")
    assert Enum.count(results) == 2
    results = Search.search(env.collection.name, "character:Daisy")
    assert Enum.count(results) == 1
    results = Search.search(env.collection.name, "character:Bogus")
    assert Enum.count(results) == 0
  end

  ## Helpers

  defp amiibo_fixture(collection, attrs \\ %{}) do
    attrs =
      Map.merge(
        %{
          name: "Fierce Dei",
          character: "Link",
          data: <<0, 1, 2, 3, 4>>,
          amiibo_id: "0100000000040002"
        },
        attrs
      )

    {:ok, amiibo} = AmiiboManager.create_amiibo(attrs)
    AmiiboManager.add_amiibo(collection, amiibo)
  end
end
