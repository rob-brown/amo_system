defmodule TournamentRunner.Driver.SquadStrike do
  defstruct [
    :tournament,
    :teams,
    teams_by_id: %{},
    remaining_matches: [],
    completed_matches: []
  ]

  require Logger

  alias TournamentRunner.Storage
  alias TournamentRunner.CommandQueue
  alias TournamentRunner.Image
  alias TournamentRunner.Script
  alias SubmissionInfo.Team
  alias SubmissionInfo.EntriesParser
  alias Challonge.Tournament
  alias Challonge.Score
  alias Challonge.Match

  @tsv_suffix "-entries.tsv"
  @match_duration :timer.seconds(450)

  @behaviour TournamentRunner.Driver

  def create_tournament(storage = %Storage{module: __MODULE__}, options \\ []) do
    {:ok, tournament_name, teams} = initial_info(storage)

    {:ok, tournament} =
      Challonge.retry(fn -> Challonge.create_tournament(tournament_name, options) end)

    state = %__MODULE__{tournament: tournament, teams: teams}
    Storage.save(storage, state)
    state
  end

  def add_participants(storage = %Storage{module: __MODULE__}) do
    state = Storage.restore(storage)
    %__MODULE__{tournament: %Tournament{}} = state

    participants = Enum.map(state.teams, &challonge_participant/1)
    :ok = Challonge.retry(fn -> Challonge.add_participants(state.tournament, participants) end)

    all_participants = Challonge.retry(fn -> Challonge.list_participants(state.tournament) end)

    teams_by_id =
      for t <- state.teams, p <- all_participants, t.team_name == p.misc, into: %{} do
        {p.id, t}
      end

    state = %__MODULE__{state | teams_by_id: teams_by_id}
    Storage.save(storage, state)
  end

  def start_tournament(storage = %Storage{module: __MODULE__}) do
    state = Storage.restore(storage)
    %__MODULE__{tournament: %Tournament{}} = state
    :ok = Challonge.retry(fn -> Challonge.start_tournament(state.tournament) end)

    Storage.save(storage, state)
    sync_with_challonge(storage)
  end

  def resume(storage = %Storage{module: __MODULE__}) do
    state = Storage.restore(storage)

    if state.remaining_matches == [] do
      Logger.warn("No more matches")
    else
      CommandQueue.queue_automation(storage)

      CommandQueue.queue_function(fn ->
        __MODULE__.resume(storage)
      end)
    end
  end

  def sync_with_challonge(storage = %Storage{module: __MODULE__}) do
    with :ok <- Challonge.retry(fn -> upload_completed_matches(storage) end),
         :ok <- Challonge.retry(fn -> download_remaining_matches(storage) end) do
      :ok
    else
      error ->
        error
    end
  end

  ## TournamentRunner.Driver callbacks

  @impl TournamentRunner.Driver
  def save_file_name(_) do
    "state.bin"
  end

  @impl TournamentRunner.Driver
  def run(storage = %Storage{module: __MODULE__}) do
    state = Storage.restore(storage)

    case state.remaining_matches do
      [match | _] ->
        team1 = Map.get(state.teams_by_id, match.p1_id)
        team2 = Map.get(state.teams_by_id, match.p2_id)
        fp_team1 = Enum.map(team1.amiibo, & &1.binary)
        fp_team2 = Enum.map(team2.amiibo, & &1.binary)
        scores = run(fp_team1, fp_team2)
        report_scores(storage, match, scores)

      _ ->
        nil
    end
  end

  defp run(team1, team2, retry_count \\ 3)

  defp run(_, _, 0) do
    Logger.error("Retries exhausted")
    {:skip, :skip}
  end

  defp run([fp1, fp2, fp3], [fp4, fp5, fp6], retry_count) do
    try do
      Script.load_squad_strike(
        bindings: [
          amiibo1: fp1,
          amiibo2: fp2,
          amiibo3: fp3,
          amiibo4: fp4,
          amiibo5: fp5,
          amiibo6: fp6
        ]
      )

      unless ready_to_fight?() do
        throw("Failed to prepare match")
      end

      Script.squad_start()

      watch_match()
      scores = determine_winner()

      Script.squad_after_match()

      scores
    catch
      "" <> error ->
        Logger.error(error)
        Joycontrol.clear_amiibo()
        Script.close_game()
        Script.launch_ssbu_to_squad_strike()
        run([fp1, fp2, fp3], [fp4, fp5, fp6], retry_count - 1)
    end
  end

  ## Helpers

  defp initial_info(%Storage{dir: dir, module: __MODULE__}) do
    bin_dir = Path.join(dir, "bins")

    dir
    |> File.ls!()
    |> Enum.find(&String.ends_with?(&1, @tsv_suffix))
    |> case do
      nil ->
        {:error, :bad_dir}

      file ->
        path = Path.join(dir, file)
        teams = path |> EntriesParser.parse_tsv() |> Enum.map(&add_binaries(&1, bin_dir))
        tournament_name = String.trim_trailing(file, @tsv_suffix)

        {:ok, tournament_name, teams}
    end
  end

  defp add_binaries(team, bin_dir) do
    amiibo =
      Enum.map(
        team.amiibo,
        &Map.put_new(&1, :binary, SubmissionInfo.binary_for_amiibo(&1, team.trainer, bin_dir))
      )

    %Team{team | amiibo: amiibo}
  end

  defp challonge_participant(team = %Team{}) do
    %{
      name: "#{team.team_name} (#{team.trainer})",
      misc: team.team_name
    }
  end

  defp upload_completed_matches(storage) do
    state = Storage.restore(storage)

    results =
      for {match, score} <- state.completed_matches do
        Challonge.retry(fn -> Challonge.post_results(state.tournament, match, score) end)
      end

    synced_match_ids =
      results
      |> Enum.filter(&match?(%Match{}, &1))
      |> MapSet.new(& &1.id)

    completed_matches =
      Enum.reject(state.completed_matches, fn {match, _} -> match.id in synced_match_ids end)

    new_state = %__MODULE__{state | completed_matches: completed_matches}
    Storage.save(storage, new_state)

    if Enum.empty?(new_state.completed_matches) do
      :ok
    else
      {:error, :upload_matches_failed}
    end
  end

  defp download_remaining_matches(storage) do
    state = Storage.restore(storage)

    case Challonge.retry(fn -> Challonge.list_matches(state.tournament) end) do
      {:error, reason} ->
        {:error, reason}

      matches ->
        remaining_matches =
          matches
          |> Enum.filter(&(&1.winner_id == nil and &1.p1_id != nil and &1.p2_id != nil))
          |> Enum.sort_by(&abs(&1.round))

        new_state = %__MODULE__{state | remaining_matches: remaining_matches}
        Storage.save(storage, new_state)
        :ok
    end
  end

  defp watch_match() do
    Vision.wait_until_found(Image.squad_victory(), @match_duration, timeout: @match_duration)
  end

  defp ready_to_fight?() do
    Vision.count(Image.squad_fp()) == {:ok, 6} and
      Vision.count(Image.squad_cpu()) == {:ok, 0}
  end

  defp determine_winner() do
    case Vision.visible(Image.squad_victory()) do
      {:ok, nil} ->
        throw("Winner not found")

      {:ok, %{x1: x, width: w}} when x / w < 0.5 ->
        Logger.info("Team 1 Wins")
        {1, 0}

      {:ok, %{x1: _}} ->
        Logger.info("Team 2 Wins")
        {0, 1}
    end
  end

  defp report_scores(storage, match, {score1, score2}) do
    state = Storage.restore(storage)
    score = Score.new(score1, score2)

    new_state = %__MODULE__{
      state
      | remaining_matches: Enum.reject(state.remaining_matches, &(&1 == match)),
        completed_matches: [{match, score} | state.completed_matches]
    }

    Storage.save(storage, new_state)
    sync_with_challonge(storage)
  end
end
