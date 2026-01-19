defmodule SquadStrike do
  defstruct [
    :tournament,
    :teams,
    teams_by_id: %{},
    remaining_matches: [],
    completed_matches: []
  ]

  require Logger

  alias SquadStrike.Storage
  alias SquadStrike.Script
  alias SubmissionInfo.Team
  alias SubmissionInfo.EntriesParser
  alias Challonge.Tournament
  alias Challonge.Score
  alias Challonge.Match

  @match_duration :timer.seconds(450)

  def create_tournament(storage = %Storage{}, options \\ []) do
    {:ok, tournament_name, teams} = initial_info(storage)

    {:ok, tournament} =
      Challonge.retry(fn -> Challonge.create_tournament(tournament_name, options) end)

    state = %__MODULE__{tournament: tournament, teams: teams}
    Storage.save(storage, state)
    state
  end

  def add_participants(storage = %Storage{}) do
    state = %__MODULE__{} = Storage.restore(storage)
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

  def start_tournament(storage = %Storage{}) do
    state = Storage.restore(storage)
    %__MODULE__{tournament: %Tournament{}} = state
    :ok = Challonge.retry(fn -> Challonge.start_tournament(state.tournament) end)

    Storage.save(storage, state)
    sync_with_challonge(storage)
  end

  def sync_with_challonge(storage = %Storage{}) do
    with :ok <- Challonge.retry(fn -> upload_completed_matches(storage) end),
         :ok <- Challonge.retry(fn -> download_remaining_matches(storage) end) do
      :ok
    else
      error ->
        error
    end
  end

  def resume(storage = %Storage{}, fetch_resolution)
      when is_function(fetch_resolution, 0) do
    state = Storage.restore(storage)

    case state.remaining_matches do
      [match | _] ->
        report_match_start(storage, match)
        team1 = Map.get(state.teams_by_id, match.p1_id)
        team2 = Map.get(state.teams_by_id, match.p2_id)
        fp_team1 = Enum.map(team1.amiibo, & &1.binary)
        fp_team2 = Enum.map(team2.amiibo, & &1.binary)
        scores = run(fp_team1, fp_team2, fetch_resolution)
        report_scores(storage, match, scores)
        resume(storage, fetch_resolution)

      [] ->
        Logger.warning("No more matches")
        :ok
    end
  end

  defp run(team1, team2, resolution, retry_count \\ 3)

  defp run(_, _, _, 0) do
    Logger.error("Retries exhausted")
    {:skip, :skip}
  end

  defp run([fp1, fp2, fp3], [fp4, fp5, fp6], fetch_resolution, retry_count) do
    try do
      # Fetch the resolution on each attempt to recover from changes.
      resolution = fetch_resolution.()

      Script.eval(
        "ss_load_squad_strike_#{resolution}",
        timeout: :timer.seconds(60),
        cwd: image_dir(resolution),
        args: %{
          amiibo1: encode_amiibo(fp1),
          amiibo2: encode_amiibo(fp2),
          amiibo3: encode_amiibo(fp3),
          amiibo4: encode_amiibo(fp4),
          amiibo5: encode_amiibo(fp5),
          amiibo6: encode_amiibo(fp6)
        }
      )

      unless ready_to_fight?(resolution) do
        throw("Failed to prepare match")
      end

      Script.eval("ss_squad_start")

      scores = watch_match(resolution)

      # Wait a few seconds to ensure the game is accepting inputs.
      Process.sleep(:timer.seconds(3))

      Script.eval("ss_after_match", timeout: :timer.seconds(35))

      scores
    catch
      "" <> error ->
        Logger.error(error)
        resolution = fetch_resolution.()

        # Maybe reboot the picopad here.
        # Though how do I reconnect?
        
        Script.eval("ss_unload_amiibo")
        Script.eval("ss_close_game", timeout: :timer.seconds(8))
        Script.eval("ss_launch_ssbu", timeout: :timer.seconds(60), cwd: image_dir(resolution))
        run([fp1, fp2, fp3], [fp4, fp5, fp6], fetch_resolution, retry_count - 1)
    end
  end

  ## Helpers

  defp initial_info(storage = %Storage{}) do
    with {:ok, tsv} <- Storage.entries_spreadsheet(storage),
         {:ok, bin_dir} <- Storage.bins_dir(storage) do
      teams = tsv |> EntriesParser.parse_tsv() |> Enum.map(&add_binaries(&1, bin_dir))
      tournament_name = Storage.tournament_name(storage)

      {:ok, tournament_name, teams}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp add_binaries(team = %Team{}, bin_dir) do
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
    state = %__MODULE__{} = Storage.restore(storage)

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
    state = %__MODULE__{} = Storage.restore(storage)

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

  defp watch_match(resolution) do
    DateTime.utc_now()
    |> DateTime.add(@match_duration, :millisecond)
    |> watch_match(resolution)
  end

  defp watch_match(deadline, resolution) do
    if DateTime.compare(DateTime.utc_now(), deadline) == :lt do
      cond do
        team1_win?(resolution) ->
          {1, 0}

        team2_win?(resolution) ->
          {0, 1}

        true ->
          # Sleep for a bit just so the CPU isn't busy-waiting.
          # This will keep the CPU cooler.
          Process.sleep(:timer.seconds(3))
          watch_match(deadline, resolution)
      end
    else
      Logger.error("Match timed out")
      {:error, :timeout}
    end
  end

  defp visible(name, resolution) do
    image = image(name, resolution)
    opts = [timeout: :timer.seconds(5), confidence: 0.8]

    case Vision.Native.visible(image, opts) do
      {:ok, nil} ->
        {:error, "Not found"}

      {:ok, info = %{}} ->
        {:ok, info}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp count_image(name, resolution) do
    image = image(name, resolution)
    opts = [timeout: :timer.seconds(5), confidence: 0.89]

    case Vision.Native.count_distinct(image, opts) do
      nil ->
        {:error, "Not found"}

      {:ok, count} ->
        {:ok, count}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ready_to_fight?(resolution) do
    count_image("ss_fp", resolution) == {:ok, 6} and
      count_image("ss_cpu", resolution) == {:ok, 0}
  end

  defp team1_win?(resolution) do
    case visible("ss_team1_victory", resolution) do
      {:error, "not found"} ->
        false

      {:ok, %{x1: _}} ->
        Logger.info("Team 1 wins")
        true

      _ ->
        false
    end
  end

  defp team2_win?(resolution) do
    case visible("ss_team2_victory", resolution) do
      {:error, "not found"} ->
        false

      {:ok, %{x1: _}} ->
        Logger.info("Team 2 wins")
        true

      _ ->
        false
    end
  end

  defp report_match_start(_storage, _match) do
    # Is it still important to notify external programs?
    # If so, how? RabbitMQ again?

    # state = Storage.restore(storage)
    # team1 = Map.get(state.teams_by_id, match.p1_id)
    # team2 = Map.get(state.teams_by_id, match.p2_id)
    # 
    # MQ.cast("match.start", %{
    # p1: %{
    # trainer: team1.trainer,
    # contact: team1.contact,
    # team_name: team1.team_name
    # },
    # p2: %{
    # trainer: team2.trainer,
    # contact: team2.contact,
    # team_name: team2.team_name
    # }
    # })
  end

  defp report_scores(storage, match, {score1, score2}) do
    state = %__MODULE__{} = Storage.restore(storage)
    score = Score.new(score1, score2)

    new_state = %__MODULE__{
      state
      | remaining_matches: Enum.reject(state.remaining_matches, &(&1 == match)),
        completed_matches: [{match, score} | state.completed_matches]
    }

    # Send to Challonge
    Storage.save(storage, new_state)
    sync_with_challonge(storage)

    # Is it still important to notify external programs?
    # If so, how? RabbitMQ again?

    # # Send to RabbitMQ
    # team1 = Map.get(state.teams_by_id, match.p1_id)
    # team2 = Map.get(state.teams_by_id, match.p2_id)
    # 
    # # !!!: This could be set up to send screenshots of the winner screen.
    # 
    # MQ.cast("match.end", %{
    # p1: %{
    # trainer: team1.trainer,
    # contact: team1.contact,
    # team_name: team1.team_name,
    # score: score1
    # },
    # p2: %{
    # trainer: team2.trainer,
    # contact: team2.contact,
    # team_name: team2.team_name,
    # score: score2
    # }
    # })
  end

  defp encode_amiibo(fp) do
    SquadStrike.DataURL.encode(fp, "application/octet-stream", :base64)
  end

  defp image(name, resolution) do
    resolution
    |> image_dir()
    |> Path.join(name <> ".png")
  end

  defp image_dir(resolution) do
    [:code.priv_dir(:squad_strike), "images", resolution]
    |> Path.join()
    |> Path.expand()
  end
end
