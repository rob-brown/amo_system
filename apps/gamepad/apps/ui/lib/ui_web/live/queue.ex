defmodule UiWeb.Queue do
  use UiWeb, :live_view

  def render(assigns) do
    ~H"""
    <h2>Amiibo Queue (<%= Enum.count(@queued_amiibo) %>)</h2>
    <%= if @loaded_amiibo_id do %>
      <div class="container amiibo-queue">
        <% a = Enum.find(@queued_amiibo, & &1.id == @loaded_amiibo_id) %>
        <.amiibo_cell amiibo={a} loaded={true}/>
        <hr/>
      </div>
    <% end %>
    <div class="container amiibo-queue">
      <%= for a <- @queued_amiibo, a.id != @loaded_amiibo_id do %>
        <.amiibo_cell amiibo={a} loaded={false}/>
      <% end %>
    </div>
    """
  end

  def amiibo_cell(assigns) do
    ~H"""
    <% class = "container amiibo-cell #{if @loaded, do: 'loaded-amiibo-cell'}" %>
    <div class={class}>
      <%= if @loaded do %>
        <h3>Loaded</h3>
      <% end %>
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
          <%= if @loaded do %>
            <button phx-click="unload-amiibo">Unload</button>
            <button phx-click="shuffle-serial" class="button-warning">Shuffle</button>
          <% else %>
            <button phx-click="load-amiibo" phx-value-id={@amiibo.id}>Load</button>
          <% end %>
          <button phx-click="queue-toggle" phx-value-id={@amiibo.id} class="button-danger">Remove</button>
        </div>
      </div>
    </div>
    """
  end
end
