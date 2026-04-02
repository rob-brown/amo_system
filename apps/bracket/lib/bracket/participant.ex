defmodule Bracket.Participant do
  @moduledoc false

  defstruct [:id, :name, :seed, metadata: %{}]

  @type t() :: %__MODULE__{
          id: binary(),
          name: binary(),
          seed: pos_integer() | nil,
          metadata: map()
        }

  @spec new(binary(), keyword()) :: t()
  def new(name, opts \\ []) do
    %__MODULE__{
      id: opts[:id] || generate_id(),
      name: name,
      seed: opts[:seed],
      metadata: opts[:metadata] || %{}
    }
  end

  defp generate_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
