defmodule UiWeb.ManageAmiiboLive do
  use UiWeb, :live_view

  require Logger

  alias AmiiboManager.Amiibo, as: A
  alias Ui.Storage
  alias AmiiboMod.Amiibo

  @impl true
  def mount(%{"id" => collection_id}, _session, socket) do
    query = ""
    id = String.to_integer(collection_id)
    collection = Storage.get_collection!(id)

    assigns = [
      queued_amiibo: [],
      tab: "browse",
      modal: "none",
      file_data: %{},
      collection: collection,
      query: query,
      search: %{query: query},
      search_results: search_amiibo(collection, query),
      loaded_amiibo_id: nil,
      tag_manager_data: UiWeb.TagManager.init()
    ]

    socket =
      socket
      |> assign(assigns)
      |> allow_upload(:bins, accept: ~w(.bin), max_entries: 100)

    {:ok, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    %{collection: collection} = socket.assigns
    socket = assign(socket, search_results: search_amiibo(collection, query), query: query)
    {:noreply, socket}
  end

  def handle_event("change-tab", %{"tab" => tab}, socket) do
    socket = assign(socket, tab: tab)
    {:noreply, socket}
  end

  def handle_event("queue-toggle", %{"id" => id}, socket) do
    %{queued_amiibo: queued_amiibo, loaded_amiibo_id: loaded_amiibo_id} = socket.assigns
    id = String.to_integer(id)

    amiibo =
      if UiWeb.Browser.selected?(id, queued_amiibo) do
        Enum.reject(queued_amiibo, &(&1.id == id))
      else
        amiibo = Storage.get_amiibo(id)
        info = create_amiibo_info(amiibo)
        Enum.uniq(queued_amiibo ++ [info])
      end

    loaded_amiibo_id =
      if id == loaded_amiibo_id do
        Joycontrol.clear_amiibo()
        nil
      else
        loaded_amiibo_id
      end

    socket = assign(socket, queued_amiibo: amiibo, loaded_amiibo_id: loaded_amiibo_id)

    {:noreply, socket}
  end

  def handle_event("load-amiibo", %{"id" => id}, socket) do
    id = String.to_integer(id)
    amiibo = Storage.get_amiibo(id)
    data = AmiiboMod.Crypto.encrypt_binary!(amiibo.data)
    Joycontrol.load_amiibo(data)
    socket = assign(socket, loaded_amiibo_id: id)
    {:noreply, socket}
  end

  def handle_event("unload-amiibo", _, socket) do
    Joycontrol.clear_amiibo()
    socket = assign(socket, loaded_amiibo_id: nil)
    {:noreply, socket}
  end

  def handle_event("dequeue-all", _params, socket) do
    socket = assign(socket, queued_amiibo: [])

    {:noreply, socket}
  end

  def handle_event("queue-all", _params, socket) do
    %{query: query, collection: collection, queued_amiibo: queued_amiibo} = socket.assigns

    new_amiibo = search_amiibo(collection, query)
    amiibo = Enum.uniq(queued_amiibo ++ new_amiibo)
    socket = assign(socket, queued_amiibo: amiibo)

    {:noreply, socket}
  end

  def handle_event("show-modal", %{"modal" => modal}, socket) do
    socket =
      if socket.assigns.modal == modal do
        assign(socket, modal: "none")
      else
        assign(socket, modal: modal)
      end

    {:noreply, socket}
  end

  def handle_event("create-tag", %{"params" => %{"new_tag_name" => tag_name}}, socket) do
    normalized = String.trim(tag_name)

    unless normalized == "" do
      # TODO: Show a flash message if possible
      AmiiboManager.upsert_tag(tag_name)
    end

    socket = assign(socket, tag_manager_data: UiWeb.TagManager.init())

    {:noreply, socket}
  end

  def handle_event("tag-amiibo", %{"params" => %{"selected_tag" => tag_name}}, socket) do
    %{queued_amiibo: queued_amiibo, collection: collection, query: query} = socket.assigns

    for a <- queued_amiibo do
      a.id |> AmiiboManager.get_amiibo() |> AmiiboManager.tag_amiibo(tag_name)
    end

    socket = assign(socket, search_results: search_amiibo(collection, query))

    {:noreply, socket}
  end

  def handle_event("untag-amiibo", %{"tag" => tag_name, "amiibo-id" => id}, socket) do
    %{collection: collection, query: query} = socket.assigns

    id = String.to_integer(id)
    amiibo = AmiiboManager.get_amiibo(id)

    AmiiboManager.untag_amiibo(amiibo, tag_name)

    socket = assign(socket, search_results: search_amiibo(collection, query))

    {:noreply, socket}
  end

  def handle_event("validate-uploads", _params, socket) do
    # TODO: Handle invalid files
    {:noreply, socket}
  end

  def handle_event("upload-bins", _params, socket) do
    %{collection: collection, query: query} = socket.assigns

    consume_uploaded_entries(socket, :bins, fn %{path: path}, _entry ->
      {:ok, amiibo} = Amiibo.read_file(path)
      AmiiboManager.add_amiibo(collection, amiibo)
      path
    end)

    socket = assign(socket, search_results: search_amiibo(collection, query))

    {:noreply, socket}
  end

  def handle_event("delete-amiibo", %{"amiibo-id" => id}, socket) do
    %{collection: collection, query: query} = socket.assigns

    id = String.to_integer(id)
    AmiiboManager.delete_amiibo(id)

    socket = assign(socket, search_results: search_amiibo(collection, query))

    {:noreply, socket}
  end

  def handle_event(event, params, socket) do
    Logger.warning("Unhandle event #{event} #{inspect(params)}")
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    Logger.warning("Unhandle msg #{inspect(msg)}")
    {:noreply, socket}
  end

  defp create_amiibo_info(a = %A{}) do
    amiibo = Amiibo.new(a.data)

    %{
      id: a.id,
      name: Amiibo.nickname(amiibo),
      image: amiibo_image_url(amiibo),
      stats: extract_stats(amiibo),
      abilities: extract_abilities(amiibo),
      tags: Enum.map(a.tags, & &1.display_name)
    }
  end

  defp amiibo_image_url(amiibo) do
    {head, tail} = Amiibo.character_info(amiibo)
    "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/icon_#{head}-#{tail}.png"
  end

  defp extract_stats(amiibo) do
    if Amiibo.ssbu_registered?(amiibo) do
      {attack, defense} = Amiibo.stats(amiibo)

      %{
        attack: attack,
        defense: defense,
        level: Amiibo.level(amiibo),
        type: Amiibo.type(amiibo),
        learning?: Amiibo.learning?(amiibo)
      }
    else
      nil
    end
  end

  defp extract_abilities(amiibo) do
    if Amiibo.ssbu_registered?(amiibo) do
      abilities = amiibo |> Amiibo.abilities() |> Enum.map(& &1.name)

      if Enum.empty?(abilities) do
        ["None"]
      else
        abilities
      end
    else
      nil
    end
  end

  def tab(assigns) do
    ~H"""
    <%= if @id == @tab do %>
      <span class="tab tab-active" phx-click="change-tab" phx-value-tab={@id}><%= @title %></span>
    <% else %>
      <span class="tab" phx-click="change-tab" phx-value-tab={@id}><%= @title %></span>
    <% end %>
    """
  end

  def search_amiibo(collection_name, query) when is_binary(collection_name) do
    collection_name
    |> Storage.search(query)
    |> Enum.map(&create_amiibo_info/1)
    |> Enum.sort_by(&(&1.name |> String.trim() |> String.downcase()))
  end

  def search_amiibo(collection, query) do
    search_amiibo(collection.name, query)
  end
end
