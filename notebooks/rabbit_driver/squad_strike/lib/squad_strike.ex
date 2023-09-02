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
  alias SquadStrike.MQ
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

  def resume(storage = %Storage{}) do
    state = Storage.restore(storage)

    case state.remaining_matches do
      [match | _] ->
        report_match_start(storage, match)
        team1 = Map.get(state.teams_by_id, match.p1_id)
        team2 = Map.get(state.teams_by_id, match.p2_id)
        fp_team1 = Enum.map(team1.amiibo, & &1.binary)
        fp_team2 = Enum.map(team2.amiibo, & &1.binary)
        scores = run(fp_team1, fp_team2)
        report_scores(storage, match, scores)
        Process.sleep(:timer.seconds(3))
        resume(storage)

      [] ->
        Logger.warn("No more matches")
        :ok
    end
  end

  defp run(team1, team2, retry_count \\ 3)

  defp run(_, _, 0) do
    Logger.error("Retries exhausted")
    {:skip, :skip}
  end

  defp run([fp1, fp2, fp3], [fp4, fp5, fp6], retry_count) do
    try do
      MQ.run_script("ss_load_squad_strike",
        timeout_ms: :timer.seconds(60),
        inputs: %{
          amiibo1: encode_amiibo(fp1),
          amiibo2: encode_amiibo(fp2),
          amiibo3: encode_amiibo(fp3),
          amiibo4: encode_amiibo(fp4),
          amiibo5: encode_amiibo(fp5),
          amiibo6: encode_amiibo(fp6)
        }
      )

      unless ready_to_fight?() do
        throw("Failed to prepare match")
      end

      MQ.run_script("ss_squad_start")

      scores = watch_match()

      MQ.run_script("ss_squad_after_match")

      scores
    catch
      "" <> error ->
        Logger.error(error)

        MQ.run_script("ss_unload_amiibo")
        MQ.run_script("ss_close_game")
        MQ.run_script("ss_launch_ssbu")
        Process.sleep(:timer.seconds(3))
        run([fp1, fp2, fp3], [fp4, fp5, fp6], retry_count - 1)
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
    DateTime.utc_now()
    |> DateTime.add(@match_duration, :millisecond)
    |> watch_match()
  end

  defp watch_match(deadline) do
    if DateTime.compare(DateTime.utc_now(), deadline) == :lt do
      cond do
        team1_win?() ->
          {1, 0}

        team2_win?() ->
          {0, 1}

        true ->
          # Sleep for a bit just so the Pi isn't busy-waiting.
          # This will keep the Pi cooler.
          Process.sleep(:timer.seconds(1))
          watch_match(deadline)
      end
    else
      Logger.error("Match timed out")
      {:error, :timeout}
    end
  end

  defp visible(image) do
    case MQ.call("image.visible", %{name: image}) do
      {:ok, info = %{"error" => nil}, _meta} ->
        {:ok, info}

      {:ok, %{"error" => error}, _meta} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp count_image(image) do
    case MQ.call("image.count", %{name: image}) do
      {:ok, %{"error" => nil, "count" => count}, _meta} ->
        {:ok, count}

      {:ok, %{"error" => error}, _meta} ->
        {:error, error}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp ready_to_fight?() do
    count_image("ss_fp") == {:ok, 6} and
      count_image("ss_cpu") == {:ok, 0}
  end

  defp team1_win?() do
    case visible("ss_team1_victory") do
      {:error, "not found"} ->
        false

      {:ok, %{"x1" => x, "width" => w}} when x / w < 0.5 ->
        Logger.info("Team 1 wins")
        true

      _ ->
        false
    end
  end

  defp team2_win?() do
    case visible("ss_team2_victory") do
      {:error, "not found"} ->
        false

      {:ok, %{"x1" => x, "width" => w}} when x / w > 0.5 ->
        Logger.info("Team 2 wins")
        true

      _ ->
        false
    end
  end

  defp report_match_start(storage, match) do
    state = Storage.restore(storage)
    team1 = Map.get(state.teams_by_id, match.p1_id)
    team2 = Map.get(state.teams_by_id, match.p2_id)

    MQ.cast("match.start", %{
      p1: %{
        trainer: team1.trainer,
        contact: team1.contact,
        team_name: team1.team_name
      },
      p2: %{
        trainer: team2.trainer,
        contact: team2.contact,
        team_name: team2.team_name
      }
    })
  end

  defp report_scores(storage, match, {score1, score2}) do
    state = Storage.restore(storage)
    score = Score.new(score1, score2)

    new_state = %__MODULE__{
      state
      | remaining_matches: Enum.reject(state.remaining_matches, &(&1 == match)),
        completed_matches: [{match, score} | state.completed_matches]
    }

    # Send to Challonge
    Storage.save(storage, new_state)
    sync_with_challonge(storage)

    # Send to RabbitMQ
    team1 = Map.get(state.teams_by_id, match.p1_id)
    team2 = Map.get(state.teams_by_id, match.p2_id)

    # !!!: This could be set up to send screenshots of the winner screen.
    # Though it would be the 640x480 resolution.

    MQ.cast("match.end", %{
      p1: %{
        trainer: team1.trainer,
        contact: team1.contact,
        team_name: team1.team_name,
        score: score1
      },
      p2: %{
        trainer: team2.trainer,
        contact: team2.contact,
        team_name: team2.team_name,
        score: score2
      }
    })
  end

  defp encode_amiibo(fp) do
    "data:application/octet-stream;base64," <> Base.encode64(fp)
  end
end
