defmodule Challonge.Tournament do
  require Logger

  defstruct [:id, :name, :description, :url]

  @type t() :: %__MODULE__{
          id: integer(),
          name: binary(),
          description: binary(),
          url: binary()
        }

  def parse(json) do
    case json do
      %{
        "tournament" => %{
          "id" => id,
          "name" => name,
          "description" => description,
          "url" => url
        }
      } ->
        {:ok, %__MODULE__{id: id, name: name, description: description, url: url}}

      other ->
        Logger.error("Bad tournament: #{inspect(other)}")
        {:error, :bad_data}
    end
  end
end
