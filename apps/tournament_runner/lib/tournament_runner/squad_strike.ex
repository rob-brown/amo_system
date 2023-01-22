defmodule TournamentRunner.SquadStrike do
  require Logger

  alias __MODULE__.State
  alias __MODULE__.Storage
  alias __MODULE__.Team
  alias Challonge.Tournament
  alias Challonge.Score
  alias Challonge.Match
  alias TournamentRunner.CommandQueue

  def create_tournament(storage = %Storage{}, options \\ []) do
    {:ok, tournament_name, teams} = Storage.initial_info(storage)

    {:ok, tournament} =
      Challonge.retry(fn -> Challonge.create_tournament(tournament_name, options) end)

    state = State.new(tournament, teams)
    Storage.save(storage, state)
  end

  def add_participants(storage = %Storage{}) do
    state = Storage.restore(storage)
    %State{tournament: %Tournament{}} = state

    participants = Enum.map(state.teams, &challonge_participant/1)
    :ok = Challonge.retry(fn -> Challonge.add_participants(state.tournament, participants) end)

    all_participants = Challonge.retry(fn -> Challonge.list_participants(state.tournament) end)

    teams_by_id =
      for t <- state.teams, p <- all_participants, t.team_name == p.misc, into: %{} do
        {p.id, t}
      end

    new_state = %State{state | teams_by_id: teams_by_id}
    Storage.save(storage, new_state)
  end

  def start_tournament(storage = %Storage{}) do
    state = Storage.restore(storage)
    %State{tournament: %Tournament{}} = state
    :ok = Challonge.retry(fn -> Challonge.start_tournament(state.tournament) end)

    Storage.save(storage, state)
    sync_with_challonge(storage)
  end

  def run(storage = %Storage{}) do
    state = Storage.restore(storage)

    case next_match_info(state) do
      {match, team1, team2} ->
        load_match(storage, match, team1, team2)

      nil ->
        Logger.warn("No more matches")
    end
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

  def challonge_participant(team = %Team{}) do
    %{
      name: "#{team.team_name} (#{team.trainer})",
      misc: team.team_name
    }
  end

  ## Helpers

  defp next_match_info(state) do
    case state.remaining_matches do
      [match | _] ->
        team1 = Map.get(state.teams_by_id, match.p1_id)
        team2 = Map.get(state.teams_by_id, match.p2_id)

        {match, team1, team2}

      _ ->
        nil
    end
  end

  defp load_match(storage, match, team1, team2) do
    fp_team1 = Enum.map(team1.amiibo, &{:memory, &1.binary})
    fp_team2 = Enum.map(team2.amiibo, &{:memory, &1.binary})

    CommandQueue.queue_squad_strike(fp_team1, fp_team2, score_reporter(storage, match))

    CommandQueue.queue_function(fn ->
      __MODULE__.run(storage)
    end)
  end

  defp score_reporter(storage, match) do
    fn
      :skip, :skip ->
        # Hopefully this doesn't happen.
        :ok

      score1, score2 ->
        state = Storage.restore(storage)
        score = Score.new(score1, score2)
        new_state = State.add_score(state, match, score)

        Storage.save(storage, new_state)
        sync_with_challonge(storage)
    end
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

    new_state = %State{state | completed_matches: completed_matches}
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
        new_state = State.set_remaining_matches(state, matches)
        Storage.save(storage, new_state)
        :ok
    end
  end
end
