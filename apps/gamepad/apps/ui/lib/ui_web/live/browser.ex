defmodule UiWeb.Browser do
  use UiWeb, :live_view

  def render(assigns) do
    ~H"""
    <div>
      <button phx-click="show-modal" phx-value-modal="uploader">Upload Amiibo</button>
      <%= unless Enum.empty?(@search_results) do %>
        <button phx-click="show-modal" phx-value-modal="tag">Tag Amiibo</button>
        <button class="button-warning" phx-click="queue-all">Queue All Amiibo</button>
        <button class="button-danger" phx-click="dequeue-all">Clear Queue</button>
      <% end %>
      <%= case @modal do %>
        <% "uploader" -> %>
          <.uploader file_data={@file_data} uploads={@uploads} />
        <% "tag" -> %>
          <UiWeb.TagManager.render selected_amiibo={@queued_amiibo} changeset={@tag_manager_data}/>

        <% _ -> %>
          <div/>
      <% end %>
    </div>
    <hr/>
    <div class="search">
      <form phx-change="search">
        <input type="text" name="query" value={@query} placeholder="Search" autofocus autocomplete="off" phx-debounce="300" />
      </form>
    </div>
    <div class="amiibo-browser">
      <%= for amiibo <- @search_results do %>
        <div class="row dir-button" phx-click="queue-toggle" phx-value-id={amiibo.id}>
          <.selectable_amiibo_cell amiibo={amiibo} queued_amiibo={@queued_amiibo}/>
        </div>
      <% end %>
    </div>
    """
  end

  def selectable_amiibo_cell(assigns) do
    ~H"""
    <%= if selected?(@amiibo, @queued_amiibo) do %>
      <img class="vertical-center" src="/images/checked.png" height="16" width="16"/>
    <% else %>
      <img class="vertical-center" src="/images/unchecked.png" height="16" width="16"/>
    <% end %>
    <div class="container amiibo-cell">
      <div class="row">
        <%= @amiibo.name %>
      </div>
      <div class="row">
        <div class="column column-30">
          <img src={@amiibo.image} height="150"/>
        </div>
        <%= if @amiibo.stats do %>
          <div class="column column-20">
            <h4>Stats</h4>
            Level: <%= @amiibo.stats.level %>
            <br/>
            Attack: <%= @amiibo.stats.attack %>
            <br/>
            Defense: <%= @amiibo.stats.defense %>
            <br/>
            Type: <%= @amiibo.stats.type %>
            <br/>
            Learning: <%= @amiibo.stats.learning? && "On" || "Off" %>
          </div>
          <div class="column column-30">
            <h4>Abilities</h4>
            <%= for ability <- @amiibo.abilities do %>
              <%= ability %><br/>
            <% end %>
          </div>
        <% else %>
          <div class="column column-50"/>
        <% end %>
        <div class="column column-20">
          <% confirm = "Are you sure you want to delete '#{@amiibo.name}'? This cannot be undone." %>
          <button class="button-danger" phx-click="delete-amiibo" phx-value-amiibo-id={@amiibo.id} data-confirm={confirm}>Delete</button>
        </div>
      </div>
      <div class="tag-container">
        <%= for tag <- @amiibo.tags do %>
          <UiWeb.Tag.render tag={tag} amiibo={@amiibo}/>
        <% end %>
      </div>
    </div>
    """
  end

  def uploader(assigns) do
    ~H"""
    <div>
      <form id="upload-form" phx-submit="upload-bins" phx-change="validate-uploads">
        <label class="phx-drop-target" phx-drop-target={@uploads.bins.ref}>
          <%= live_file_input @uploads.bins %>
          <p>Drop your .bin files here.</p>
          <div>Choose Files</div>
        </label>
        <input type="submit" value="Upload"/>
        <%= for entry <- @uploads.bins.entries do %>
          <div class="upload-entry">
            <%= entry.client_name %>
            <%= for err <- upload_errors(@uploads.bins, entry) do %>
              <p class="alert alert-danger"><%= error_to_string(err) %></p>
            <% end %>
          </div>
        <% end %>
      </form>
    </div>
    """
  end

  def selected?(id, queued_amiibo) when is_integer(id) do
    Enum.any?(queued_amiibo, &(&1.id == id))
  end

  def selected?(amiibo, queued_amiibo) do
    selected?(amiibo.id, queued_amiibo)
  end

  defp error_to_string(:too_large), do: "Too large"
  defp error_to_string(:too_many_files), do: "You have selected too many files"
  defp error_to_string(:not_accepted), do: "You have selected an unacceptable file type"
end
