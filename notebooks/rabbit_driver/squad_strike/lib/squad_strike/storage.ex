defmodule SquadStrike.Storage do
  @enforce_keys [:dir]
  defstruct [:dir]

  @type t() :: %__MODULE__{dir: binary()}

  def new(dir) when is_binary(dir) do
    dir = Path.expand(dir)

    if File.dir?(dir) do
      %__MODULE__{dir: dir}
    else
      raise "Not a directory"
    end
  end

  def save(%__MODULE__{dir: dir}, state) do
    dir
    |> Path.join(save_file_name())
    |> File.write(:erlang.term_to_binary(state))
    |> case do
      :ok ->
        {:ok, state}

      other ->
        other
    end
  end

  def restore(%__MODULE__{dir: dir}) do
    dir
    |> Path.join(save_file_name())
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  def save_file_name() do
    "state.bin"
  end
end
