defmodule AmiiboManagerTest do
  use ExUnit.Case
  doctest AmiiboManager

  alias AmiiboManager.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.checkin(Repo) end)
  end

  test "create collection" do
    name = "test collection"
    AmiiboManager.create_collection(name)

    c = AmiiboManager.get_collection(name)

    assert c != nil
    assert c.name == name
  end

  test "create amiibo" do
    {:ok, amiibo} = amiibo_fixture()
    assert amiibo != nil
    assert amiibo.name == "Fierce Dei"
  end

  test "add amiibo to collection" do
    name = "non-empty collection"
    AmiiboManager.create_collection(name)

    {:ok, amiibo} = amiibo_fixture()

    AmiiboManager.add_amiibo(name, amiibo)
    c = AmiiboManager.get_collection(name)

    assert c != nil
    assert Enum.count(c.amiibo) == 1
    assert hd(c.amiibo).collection != nil
  end

  test "tag amiibo" do
    name = "tagged amiibo collection"
    AmiiboManager.create_collection(name)

    {:ok, amiibo} = amiibo_fixture()
    {:ok, amiibo} = AmiiboManager.add_amiibo(name, amiibo)

    AmiiboManager.tag_amiibo(amiibo, "TEST")

    c = AmiiboManager.get_collection(name)

    assert c.amiibo
           |> hd()
           |> then(& &1.tags)
           |> hd()
           |> then(& &1.slug) == "test"
  end

  test "should add multiple tags to amiibo" do
    name = "tagged amiibo collection"
    AmiiboManager.create_collection(name)

    {:ok, amiibo} = amiibo_fixture()
    {:ok, amiibo} = AmiiboManager.add_amiibo(name, amiibo)

    AmiiboManager.tag_amiibo(amiibo, "FIRST TAG")
    AmiiboManager.tag_amiibo(amiibo, "SECOND TAG")
    c = AmiiboManager.get_collection(name)

    assert [_, _] = hd(c.amiibo).tags
  end

  test "untag amiibo" do
    name = "untagged amiibo collection"
    AmiiboManager.create_collection(name)

    {:ok, amiibo} = amiibo_fixture()
    {:ok, amiibo} = AmiiboManager.add_amiibo(name, amiibo)
    {:ok, amiibo} = AmiiboManager.tag_amiibo(amiibo, "TEST")

    amiibo = AmiiboManager.get_amiibo(amiibo.id)

    assert [tag] = amiibo.tags
    assert tag.slug == "test"

    AmiiboManager.untag_amiibo(amiibo, "TEST")
    c = AmiiboManager.get_collection(name)

    assert [] = Enum.flat_map(c.amiibo, & &1.tags)
  end

  ## Helpers

  defp amiibo_fixture(attrs \\ %{}) do
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

    AmiiboManager.create_amiibo(attrs)
  end
end
