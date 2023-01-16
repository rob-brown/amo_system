defmodule Challonge.Participant do
  require Logger

  defstruct [:id, :name, :misc]

  @type t() :: %__MODULE__{
          id: integer(),
          name: binary(),
          misc: binary()
        }

  def parse(json) do
    case json do
      %{
        "participant" => %{
          "id" => id,
          "name" => name,
          "misc" => misc
        }
      } ->
        {:ok, %__MODULE__{id: id, name: name, misc: misc}}

      other ->
        Logger.error("Bad particpant #{inspect(other)}")
        {:error, :bad_data}
    end
  end
end
