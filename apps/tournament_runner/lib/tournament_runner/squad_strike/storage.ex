defmodule TournamentRunner.SquadStrike.Storage do
  @enforce_keys [:dir]
  defstruct [:dir]

  alias TournamentRunner.SquadStrike.State
  alias TournamentRunner.SquadStrike.Team

  @tsv_suffix "-entries.tsv"

  def new(dir) do
    dir = Path.expand(dir)

    if File.dir?(dir) do
      %__MODULE__{dir: dir}
    else
      raise "Not a directory"
    end
  end

  def initial_info(%__MODULE__{dir: dir}) do
    bin_dir = Path.join(dir, "bins")

    dir
    |> File.ls!()
    |> Enum.find(&String.ends_with?(&1, @tsv_suffix))
    |> case do
      nil ->
        {:error, :bad_dir}

      file ->
        path = Path.join(dir, file)
        teams = path |> Team.parse_tsv() |> Enum.map(&add_binaries(&1, bin_dir))
        tournament_name = String.trim_trailing(file, @tsv_suffix)

        {:ok, tournament_name, teams}
    end
  end

  @spec save(%__MODULE__{}, %State{}) :: {:ok, %State{}} | {:error, any()}
  def save(%__MODULE__{dir: dir}, state = %State{}) do
    dir
    |> Path.join("state.bin")
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
    |> Path.join("state.bin")
    |> File.read!()
    |> :erlang.binary_to_term()
  end

  ## Helpers

  defp add_binaries(team, bin_dir) do
    %Team{
      team
      | amiibo:
          Enum.map(
            team.amiibo,
            &Map.put_new(&1, :binary, binary_for_amiibo(&1, team.trainer, bin_dir))
          )
    }
  end

  defp binary_for_amiibo(amiibo, trainer_name, bin_dir) do
    trainer_name
    |> filename(amiibo.character, amiibo.name)
    |> Path.expand(bin_dir)
    |> File.read!()
  end

  defp filename(trainer, character, nickname) do
    [trainer, character, nickname]
    |> Enum.map(&(&1 |> String.trim() |> sanitize_for_fs()))
    |> Enum.join("-")
    |> then(&(&1 <> ".bin"))
  end

  def sanitize_for_fs(text, replacement \\ "+") do
    String.replace(text, ~r{\\|/|<|>|:|"|'|\?|\*|\||_}, replacement)
  end
end
