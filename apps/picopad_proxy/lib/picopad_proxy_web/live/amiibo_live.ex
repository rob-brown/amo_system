defmodule PicopadProxyWeb.AmiiboLive do
  use PicopadProxyWeb, :live_view

  alias AmiiboManager
  alias PicopadProxy.ConnectionManager

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(PicopadProxy.PubSub, "picopad:events")
    end

    import Ecto.Query

    # Get all collections
    collections = AmiiboManager.Repo.all(AmiiboManager.Collection)

    # Create default if none exist
    {collections, selected_collection} =
      if Enum.empty?(collections) do
        {:ok, default} = AmiiboManager.create_collection("default")
        {[default], default}
      else
        {collections, List.first(collections)}
      end

    # Get amiibos for selected collection
    amiibos =
      if selected_collection do
        AmiiboManager.Repo.all(
          from(a in AmiiboManager.Amiibo,
            where: a.collection_id == ^selected_collection.id
          )
        )
        |> Enum.map(&enrich_amiibo/1)
      else
        []
      end

    socket =
      socket
      |> assign(:collections, collections)
      |> assign(:selected_collection, selected_collection)
      |> assign(:amiibos, amiibos)
      |> assign(:selected_amiibo, nil)
      |> assign(:show_create_collection, false)
      |> assign(:new_collection_name, "")
      |> allow_upload(:amiibo_file,
        accept: ~w(.bin),
        max_entries: 10,
        max_file_size: 1_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_event("select_collection", %{"id" => id}, socket) do
    import Ecto.Query
    collection_id = String.to_integer(id)
    collection = Enum.find(socket.assigns.collections, &(&1.id == collection_id))

    amiibos =
      AmiiboManager.Repo.all(
        from(a in AmiiboManager.Amiibo,
          where: a.collection_id == ^collection_id
        )
      )
      |> Enum.map(&enrich_amiibo/1)

    {:noreply, assign(socket, selected_collection: collection, amiibos: amiibos)}
  end

  @impl true
  def handle_event("show_create_collection", _, socket) do
    {:noreply, assign(socket, show_create_collection: true)}
  end

  @impl true
  def handle_event("hide_create_collection", _, socket) do
    {:noreply, assign(socket, show_create_collection: false, new_collection_name: "")}
  end

  @impl true
  def handle_event("update_collection_name", %{"name" => name}, socket) do
    {:noreply, assign(socket, new_collection_name: name)}
  end

  @impl true
  def handle_event("create_collection", _, socket) do
    case AmiiboManager.create_collection(socket.assigns.new_collection_name) do
      {:ok, collection} ->
        collections = socket.assigns.collections ++ [collection]

        socket =
          socket
          |> assign(:collections, collections)
          |> assign(:selected_collection, collection)
          |> assign(:amiibos, [])
          |> assign(:show_create_collection, false)
          |> assign(:new_collection_name, "")
          |> put_flash(:info, "Created collection: #{collection.name}")

        {:noreply, socket}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to create collection")}
    end
  end

  @impl true
  def handle_event("delete_collection", %{"id" => id}, socket) do
    collection_id = String.to_integer(id)
    collection = Enum.find(socket.assigns.collections, &(&1.id == collection_id))

    if collection do
      case AmiiboManager.delete_collection(collection_id) do
        {:ok, _} ->
          collections = Enum.reject(socket.assigns.collections, &(&1.id == collection_id))

          # If we deleted the selected collection, select another one
          {new_selected, new_amiibos} =
            if socket.assigns.selected_collection &&
                 socket.assigns.selected_collection.id == collection_id do
              case List.first(collections) do
                nil ->
                  {nil, []}

                new_coll ->
                  import Ecto.Query

                  amiibos =
                    AmiiboManager.Repo.all(
                      from(a in AmiiboManager.Amiibo,
                        where: a.collection_id == ^new_coll.id
                      )
                    )

                  {new_coll, amiibos}
              end
            else
              {socket.assigns.selected_collection, socket.assigns.amiibos}
            end

          socket =
            socket
            |> assign(:collections, collections)
            |> assign(:selected_collection, new_selected)
            |> assign(:amiibos, new_amiibos)
            |> put_flash(:info, "Deleted collection: #{collection.name}")

          {:noreply, socket}

        {:error, _} ->
          {:noreply, put_flash(socket, :error, "Failed to delete collection")}
      end
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_amiibo", %{"id" => id}, socket) do
    amiibo = Enum.find(socket.assigns.amiibos, &(&1.id == String.to_integer(id)))
    {:noreply, assign(socket, :selected_amiibo, amiibo)}
  end

  @impl true
  def handle_event("load_amiibo", %{"id" => id}, socket) do
    amiibo = Enum.find(socket.assigns.amiibos, &(&1.id == String.to_integer(id)))

    encrypted_data = AmiiboSerialization.encrypt_binary!(amiibo.data)

    case ConnectionManager.load_amiibo(encrypted_data) do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Loaded #{amiibo.name} to Picopad")
          |> assign(:selected_amiibo, amiibo)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to load amiibo: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("clear_amiibo", _params, socket) do
    case ConnectionManager.clear_amiibo() do
      :ok ->
        socket =
          socket
          |> put_flash(:info, "Cleared amiibo from Picopad")
          |> assign(:selected_amiibo, nil)

        {:noreply, socket}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, "Failed to clear amiibo: #{inspect(reason)}")}
    end
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :amiibo_file, ref)}
  end

  @impl true
  def handle_event("save_upload", _params, socket) do
    collection = socket.assigns.selected_collection

    if collection do
      uploaded_files =
        consume_uploaded_entries(socket, :amiibo_file, fn %{path: path}, _entry ->
          with {:ok, binary} <- File.read(path) do
            encrypted? = AmiiboSerialization.encrypted?(binary)

            decrypt_result =
              if encrypted? do
                AmiiboSerialization.decrypt_binary(binary)
              else
                {:ok, binary}
              end

            case decrypt_result do
              {:ok, decrypted} ->
                amiibo =
                  try do
                    AmiiboSerialization.Amiibo.new(decrypted)
                  rescue
                    _e ->
                      nil
                  end

                if amiibo do
                  case AmiiboManager.add_amiibo(collection, amiibo) do
                    {:ok, saved_amiibo} ->
                      {:ok, saved_amiibo}

                    {:error, changeset} ->
                      errors =
                        Ecto.Changeset.traverse_errors(changeset, fn {msg, _} -> msg end)

                      {:postpone, "Failed to save: #{inspect(errors)}"}
                  end
                else
                  {:postpone, "Invalid amiibo format - unexpected size"}
                end

              {:error, reason} ->
                {:postpone, "Decryption failed: #{inspect(reason)}"}

              nil ->
                {:postpone, "Decryption returned nil"}

              _other ->
                {:postpone, "Unexpected decryption result"}
            end
          else
            {:error, reason} ->
              {:postpone, "Failed to read file: #{inspect(reason)}"}
          end
        end)

      import Ecto.Query

      amiibos =
        AmiiboManager.Repo.all(
          from(a in AmiiboManager.Amiibo,
            where: a.collection_id == ^collection.id
          )
        )
        |> Enum.map(&enrich_amiibo/1)

      count = length(uploaded_files)

      socket =
        socket
        |> assign(:amiibos, amiibos)
        |> put_flash(:info, "Uploaded #{count} amiibo")

      {:noreply, socket}
    else
      {:noreply, put_flash(socket, :error, "No collection selected")}
    end
  end

  @impl true
  def handle_event("delete_amiibo", %{"id" => id}, socket) do
    import Ecto.Query
    amiibo_id = String.to_integer(id)
    collection = socket.assigns.selected_collection

    AmiiboManager.delete_amiibo(amiibo_id)

    amiibos =
      AmiiboManager.Repo.all(
        from(a in AmiiboManager.Amiibo,
          where: a.collection_id == ^collection.id
        )
      )
      |> Enum.map(&enrich_amiibo/1)

    socket =
      socket
      |> assign(:amiibos, amiibos)
      |> put_flash(:info, "Deleted amiibo")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:picopad_event, {:amiibo_loaded, _info}}, socket) do
    {:noreply, put_flash(socket, :info, "Amiibo loaded successfully")}
  end

  @impl true
  def handle_info({:picopad_event, :amiibo_cleared}, socket) do
    {:noreply, assign(socket, :selected_amiibo, nil)}
  end

  @impl true
  def handle_info(_msg, socket) do
    {:noreply, socket}
  end

  defp enrich_amiibo(amiibo) do
    a = AmiiboSerialization.Amiibo.new(amiibo.data)

    Map.merge(amiibo, %{
      image: amiibo_image_url(a),
      stats: extract_stats(a),
      abilities: extract_abilities(a)
    })
  end

  defp amiibo_image_url(amiibo) do
    {head, tail} = SSBU.character_info(amiibo)
    "https://raw.githubusercontent.com/N3evin/AmiiboAPI/master/images/icon_#{head}-#{tail}.png"
  end

  defp extract_stats(amiibo) do
    if SSBU.ssbu_registered?(amiibo) do
      {attack, defense} = SSBU.stats(amiibo)

      %{
        attack: attack,
        defense: defense,
        level: SSBU.level(amiibo),
        type: SSBU.type(amiibo),
        learning?: SSBU.learning?(amiibo)
      }
    else
      nil
    end
  end

  defp extract_abilities(amiibo) do
    if SSBU.ssbu_registered?(amiibo) do
      abilities = amiibo |> SSBU.abilities() |> Enum.map(& &1.name)

      if Enum.empty?(abilities) do
        ["None"]
      else
        abilities
      end
    else
      []
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <div class="mb-4">
        <.link navigate="/" class="text-blue-600 hover:text-blue-800">← Back to Home</.link>
      </div>

      <h1 class="text-4xl font-bold mb-8">Amiibo Management</h1>
      
    <!-- Collection Selector -->
      <div class="bg-white shadow rounded-lg p-6 mb-6">
        <div class="flex items-center justify-between mb-4">
          <h2 class="text-2xl font-semibold">Collections</h2>
          <div class="flex gap-2">
            <button
              phx-click="show_create_collection"
              class="px-4 py-2 bg-green-500 text-white rounded hover:bg-green-600"
            >
              + New Collection
            </button>
            <%= if @selected_collection do %>
              <button
                phx-click="delete_collection"
                phx-value-id={@selected_collection.id}
                data-confirm={"Are you sure you want to delete '#{@selected_collection.name}'? This will delete all amiibo in it."}
                class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
              >
                Delete Collection
              </button>
            <% end %>
          </div>
        </div>

        <%= if @show_create_collection do %>
          <div class="mb-4 p-4 bg-gray-50 rounded">
            <form phx-submit="create_collection">
              <div class="flex gap-2">
                <input
                  type="text"
                  value={@new_collection_name}
                  phx-change="update_collection_name"
                  name="name"
                  placeholder="Collection name"
                  class="flex-1 px-3 py-2 border border-gray-300 rounded"
                />
                <button
                  type="submit"
                  class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600"
                >
                  Create
                </button>
                <button
                  type="button"
                  phx-click="hide_create_collection"
                  class="px-4 py-2 bg-gray-300 text-gray-700 rounded hover:bg-gray-400"
                >
                  Cancel
                </button>
              </div>
            </form>
          </div>
        <% end %>

        <div class="flex gap-2 flex-wrap">
          <%= for collection <- @collections do %>
            <button
              phx-click="select_collection"
              phx-value-id={collection.id}
              class={
                if @selected_collection && collection.id == @selected_collection.id,
                  do: "px-4 py-2 bg-blue-500 text-white rounded",
                  else: "px-4 py-2 bg-gray-200 text-gray-700 rounded hover:bg-gray-300"
              }
            >
              {collection.name}
            </button>
          <% end %>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6 mb-6">
        <!-- Current Amiibo -->
        <div class="bg-white shadow rounded-lg p-6">
          <h2 class="text-2xl font-semibold mb-4">Current Amiibo</h2>

          <%= if @selected_amiibo do %>
            <div class="p-4 bg-blue-50 rounded mb-4">
              <div class="font-medium">{@selected_amiibo.name}</div>
              <div class="text-sm text-gray-600">{@selected_amiibo.character}</div>
              <div class="text-xs text-gray-500 mt-1">Loaded on Picopad</div>
            </div>

            <button
              phx-click="clear_amiibo"
              class="w-full px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600"
            >
              Clear Amiibo
            </button>
          <% else %>
            <p class="text-gray-500 mb-2">No amiibo currently loaded</p>
            <p class="text-sm text-gray-400">Select an amiibo below to load it.</p>
          <% end %>
        </div>
        
    <!-- Upload -->
        <div class="lg:col-span-2 bg-white shadow rounded-lg p-6">
          <h2 class="text-2xl font-semibold mb-4">Upload Amiibo</h2>

          <%= if @selected_collection do %>
            <p class="text-sm text-gray-600 mb-4">
              Uploading to: <span class="font-semibold">{@selected_collection.name}</span>
            </p>

            <form phx-submit="save_upload" phx-change="validate_upload">
              <div
                class="border-2 border-dashed border-gray-300 rounded-lg p-8 text-center mb-4"
                phx-drop-target={@uploads.amiibo_file.ref}
              >
                <.live_file_input upload={@uploads.amiibo_file} class="hidden" />
                <label for={@uploads.amiibo_file.ref} class="cursor-pointer">
                  <div class="text-gray-600 text-lg">
                    Click to select or drag & drop
                  </div>
                  <div class="text-sm text-gray-400 mt-2">
                    Upload multiple .bin files at once
                  </div>
                </label>
              </div>

              <%= if length(@uploads.amiibo_file.entries) > 0 do %>
                <div class="mb-4 space-y-2">
                  <%= for entry <- @uploads.amiibo_file.entries do %>
                    <div class="flex items-center justify-between p-3 bg-gray-50 rounded">
                      <span class="text-sm font-medium">{entry.client_name}</span>
                      <button
                        type="button"
                        phx-click="cancel_upload"
                        phx-value-ref={entry.ref}
                        class="text-red-600 hover:text-red-800 font-bold"
                      >
                        ×
                      </button>
                    </div>
                  <% end %>
                </div>

                <button
                  type="submit"
                  class="w-full px-4 py-3 bg-blue-500 text-white rounded hover:bg-blue-600 font-semibold"
                >
                  Upload {length(@uploads.amiibo_file.entries)} File(s)
                </button>
              <% end %>
            </form>
          <% else %>
            <p class="text-gray-500">Please select or create a collection first.</p>
          <% end %>
        </div>
      </div>
      
    <!-- Amiibo Grid -->
      <div class="bg-white shadow rounded-lg p-6">
        <h2 class="text-2xl font-semibold mb-4">
          <%= if @selected_collection do %>
            {@selected_collection.name} Collection
          <% else %>
            Amiibo Collection
          <% end %>
        </h2>

        <%= if length(@amiibos) == 0 do %>
          <div class="text-center py-12">
            <p class="text-gray-500 text-lg">No amiibo in this collection yet</p>
            <p class="text-sm text-gray-400 mt-2">Upload .bin files to get started.</p>
          </div>
        <% else %>
          <div class="space-y-4">
            <%= for amiibo <- @amiibos do %>
              <div class="border-2 border-gray-200 rounded-lg p-4 hover:border-blue-400 transition-colors">
                <h3 class="text-xl font-bold mb-3">{amiibo.name}</h3>
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                  <!-- Image -->
                  <div class="flex justify-center items-start">
                    <img src={amiibo.image} alt={amiibo.name} class="h-40 object-contain" />
                  </div>
                  
    <!-- Stats -->
                  <%= if amiibo.stats do %>
                    <div>
                      <h4 class="font-semibold text-lg mb-2">Stats</h4>
                      <div class="text-sm space-y-1">
                        <div>Level: {amiibo.stats.level}</div>
                        <div>Attack: {amiibo.stats.attack}</div>
                        <div>Defense: {amiibo.stats.defense}</div>
                        <div>Type: {amiibo.stats.type}</div>
                        <div>Learning: {if amiibo.stats.learning?, do: "On", else: "Off"}</div>
                      </div>
                    </div>
                    
    <!-- Abilities -->
                    <div>
                      <h4 class="font-semibold text-lg mb-2">Abilities</h4>
                      <div class="text-sm space-y-1">
                        <%= for ability <- amiibo.abilities do %>
                          <div>{ability}</div>
                        <% end %>
                      </div>
                    </div>
                  <% else %>
                    <div class="md:col-span-2">
                      <p class="text-gray-500 text-sm">
                        Not registered for Super Smash Bros. Ultimate
                      </p>
                    </div>
                  <% end %>
                  
    <!-- Actions -->
                  <div class="flex flex-col gap-2">
                    <button
                      phx-click="load_amiibo"
                      phx-value-id={amiibo.id}
                      class="px-4 py-2 bg-blue-500 text-white rounded hover:bg-blue-600 font-medium"
                    >
                      Load to Picopad
                    </button>
                    <button
                      phx-click="delete_amiibo"
                      phx-value-id={amiibo.id}
                      data-confirm={"Are you sure you want to delete '#{amiibo.name}'? This cannot be undone."}
                      class="px-4 py-2 bg-red-500 text-white rounded hover:bg-red-600 font-medium"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>
        <% end %>
      </div>
    </div>
    """
  end
end
