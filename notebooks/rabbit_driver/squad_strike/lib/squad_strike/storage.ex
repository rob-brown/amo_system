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

  def save(storage = %__MODULE__{dir: dir}, state) do
    file_name = SquadStrike.save_file_name(storage)

    dir
    |> Path.join(file_name)
    |> File.write(:erlang.term_to_binary(state))
    |> case do
      :ok ->
        {:ok, state}

      other ->
        other
    end
  end

  def restore(storage = %__MODULE__{dir: dir}) do
    file_name = SquadStrike.save_file_name(storage)

    dir
    |> Path.join(file_name)
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  def save_file_name(storage = %__MODULE__{}) do
    "state.bin"
  end
end
