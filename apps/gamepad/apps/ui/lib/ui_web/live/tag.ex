defmodule UiWeb.Tag do
  use UiWeb, :live_view

  def render(assigns) do
    ~H"""
    <% confirm = "Are you sure you want to remove tag '#{@tag}' from #{@amiibo.name}?" %>
    <div class="tag image-box" phx-click="untag-amiibo" phx-value-tag={@tag} phx-value-amiibo-id={@amiibo.id} data-confirm={confirm}>
      <img class="main-image" style="width: auto; height: 10pt; margin-top: 6pt; margin-bottom: -1pt;" src="/images/tag.png"/>
      <img class="hover-image" style="width: auto; height: 10pt; margin-top: 6pt; margin-bottom: -1pt;" src="/images/delete.png"/>
      <%= @tag %>
    </div>
    """
  end
end
