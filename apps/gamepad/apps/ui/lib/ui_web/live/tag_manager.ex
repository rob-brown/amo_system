defmodule UiWeb.TagManager do
  use UiWeb, :live_view

  alias Ui.Storage

  def init() do
    __MODULE__.Params.changeset()
  end

  def render(assigns) do
    ~H"""
    <div class="container">
      <div class="row">
        <div class="column column-50">
          <%= form_for @changeset, "#", [phx_submit: "tag-amiibo"], fn f -> %>
            <%= select f, :selected_tag, tag_options() %>
            <br/>
            <%= submit "Tag Queued Amiibo", class: "button-success" %> 
          <% end %>
        </div>

        <div class="column column-50">
          <%= form_for @changeset, "#", [phx_submit: "create-tag"], fn f -> %>
            <%= text_input f, :new_tag_name, placeholder: "Tag Name" %>
            <%= submit "Create New Tag", class: "button-success" %> 
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  defp tag_options() do
    Storage.list_tags()
    |> Enum.map(&{&1.display_name, &1.slug})
  end

  defmodule Params do
    use Ecto.Schema
    import Ecto.Changeset

    schema "tag_data" do
      field(:selected_tag, :string, default: nil)
      field(:new_tag_name, :string, default: nil)
    end

    def changeset(attrs \\ %{}) do
      slugs = Enum.map(Ui.Storage.list_tags(), & &1.slug)

      %__MODULE__{}
      |> cast(attrs, [:selected_tag, :new_tag_name])
      |> validate_inclusion(:selected_tag, slugs)
    end
  end
end
