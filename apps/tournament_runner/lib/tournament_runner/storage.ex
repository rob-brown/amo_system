defmodule TournamentRunner.Storage do
  @enforce_keys [:dir, :module]
  defstruct [:dir, :module]

  alias TournamentRunner.Driver

  @behaviour Driver

  @type t() :: %__MODULE__{
          dir: binary(),
          module: atom()
        }

  def new(dir, module) when is_binary(dir) and is_atom(module) do
    dir = Path.expand(dir)

    if File.dir?(dir) do
      %__MODULE__{dir: dir, module: module}
    else
      raise "Not a directory"
    end
  end

  def save(%__MODULE__{dir: dir, module: module}, state) do
    file_name = module.save_file_name()

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

  def restore(%__MODULE__{dir: dir, module: module}) do
    file_name = module.save_file_name(module.new())

    dir
    |> Path.join(file_name)
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  ## TournamentRunner.Driver callbacks

  @impl Driver
  def save_file_name(storage = %__MODULE__{module: module}) do
    module.save_file_name(storage)
  end

  @impl Driver
  def run(storage = %__MODULE__{module: module}) do
    storage
    |> restore()
    |> module.run()
  end
end
