defmodule SquadStrike.Storage do
  @enforce_keys [:dir]
  defstruct [:dir]

  @type t() :: %__MODULE__{dir: binary()}

  @tsv_suffix "-entries.tsv"

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

  def tournament_name(storage = %__MODULE__{}) do
    {:ok, tsv} = entries_spreadsheet(storage)

    tsv
    |> Path.basename()
    |> String.trim_trailing(@tsv_suffix)
  end

  def entries_spreadsheet(%__MODULE__{dir: dir}) do
    dir
    |> File.ls!()
    |> Enum.find(&String.ends_with?(&1, @tsv_suffix))
    |> case do
      nil ->
        {:error, "Missing entries spreadsheet"}

      name ->
        {:ok, Path.expand(name, dir)}
    end
  end

  def bins_dir(%__MODULE__{dir: dir}) do
    path = Path.expand("bins", dir)

    if File.dir?(path) do
      {:ok, path}
    else
      {:error, "Missing bins"}
    end
  end
end
