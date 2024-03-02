defmodule TournamentRunner.Driver.Match1v1 do
  defstruct [
    :tournament,
    :amiibo,
    :best_of,
    amiibo_by_id: %{},
    remaining_matches: [],
    completed_matches: []
  ]

  require Logger
  require Integer

  alias TournamentRunner.Storage
  alias TournamentRunner.CommandQueue
  alias TournamentRunner.Image
  alias TournamentRunner.Script
  alias SubmissionInfo.Amiibo
  alias SubmissionInfo.AmiiboParser
  alias Challonge.Tournament
  alias Challonge.Score
  alias Challonge.Match

  @tsv_suffix "-amiibo.tsv"
  @match_duration :timer.seconds(450)

  @behaviour TournamentRunner.Driver

  # TODO: Create option for best of 3.

  def create_tournament(storage = %Storage{module: __MODULE__}, options \\ []) do
    {:ok, tournament_name, amiibo} = initial_info(storage)
    {best_of, options} = best_of_count(options)

    {:ok, tournament} =
      Challonge.retry(fn -> Challonge.create_tournament(tournament_name, options) end)

    state = %__MODULE__{tournament: tournament, amiibo: amiibo, best_of: best_of}
    Storage.save(storage, state)
    state
  end

  def add_participants(storage = %Storage{module: __MODULE__}) do
    state = Storage.restore(storage)
    %__MODULE__{tournament: %Tournament{}} = state

    participants = Enum.map(state.amiibo, &challonge_participant/1)
    :ok = Challonge.retry(fn -> Challonge.add_participants(state.tournament, participants) end)

    all_participants = Challonge.retry(fn -> Challonge.list_participants(state.tournament) end)

    amiibo_by_id =
      for a <- state.amiibo, p <- all_participants, a.name == p.misc, into: %{} do
        {p.id, a}
      end

    state = %__MODULE__{state | amiibo_by_id: amiibo_by_id}
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
        fp1 = state.amiibo_by_id |> Map.get(match.p1_id) |> then(& &1.binary)
        fp2 = state.amiibo_by_id |> Map.get(match.p2_id) |> then(& &1.binary)
        scores = run(fp1, fp2, state.best_of)
        report_scores(storage, match, scores)

      _ ->
        nil
    end
  end

  defp run(fp1, fp2, best_of, retry_count \\ 3)

  defp run(_, _, _, 0) do
    Logger.error("Retries exhausted")
    {:skip, :skip}
  end

  defp run(fp1, fp2, best_of, retry_count) do
    try do
      {:ok, amiibo_count} = Vision.Native.count(Image.fp())

      cond do
        amiibo_count == 0 ->
          Script.load_initial_1v1(bindings: [amiibo1: fp1, amiibo2: fp2])

        amiibo_count == 2 ->
          Script.load_subsequent_1v1(bindings: [amiibo1: fp1, amiibo2: fp2])

        true ->
          throw("Previously loaded amiibo detected")
      end

      case check_ready_to_fight() do
        :ok ->
          :ok

        {:error, reason} ->
          throw("Failed to prepare match: #{inspect(reason)}")
      end

      # Start the match
      Joycontrol.command("plus")

      scores =
        if best_of == 1 do
          watch_match(@match_duration)
          Script.advance_to_scores()
          determine_winner()
        else
          watch_match(@match_duration * best_of)
          # Get a screenshot for debugging.
          Joycontrol.command(:capture)
          {s1, s2} = best_of_n_scores(best_of)
          Script.advance_to_scores()
          Joycontrol.command(:capture)

          # Match the scores to the winner/loser.
          case determine_winner() do
            {1, 0} ->
              {s1, s2}

            {0, 1} ->
              {s2, s1}
          end
        end

      Logger.debug("Scores: #{inspect(scores)}")

      Script.after_match()

      # TODO: Clear the cache only if an amiibo comes up twice.
      Script.clear_amiibo_cache()

      scores
    catch
      "" <> error ->
        Logger.error(error)
        Joycontrol.clear_amiibo()
        Script.close_game()
        Script.launch_ssbu_to_smash_menu()
        run(fp1, fp2, best_of, retry_count - 1)
    end
  end

  ## Helpers

  defp best_of_count(options) do
    # Get the value and remove it so it doesn't go to Challonge.
    {best_of, options} = Keyword.pop(options, :best_of, 1)

    if Integer.is_even(best_of) do
      throw(":best_of must be odd, got #{best_of}")
    end

    {best_of, options}
  end

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
        amiibo = path |> AmiiboParser.parse_tsv() |> Enum.map(&add_binaries(&1, bin_dir))
        tournament_name = String.trim_trailing(file, @tsv_suffix)

        {:ok, tournament_name, amiibo}
    end
  end

  defp add_binaries(amiibo, bin_dir) do
    binary = SubmissionInfo.binary_for_amiibo(amiibo, amiibo.trainer, bin_dir)

    %Amiibo{amiibo | binary: binary}
  end

  defp challonge_participant(amiibo = %Amiibo{}) do
    %{
      name: "#{amiibo.name} (#{amiibo.trainer})",
      misc: amiibo.name
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

  defp watch_match(timeout) when is_integer(timeout) do
    DateTime.utc_now()
    |> DateTime.add(timeout, :millisecond)
    |> watch_match()
  end

  defp watch_match(deadline = %DateTime{}) do
    if DateTime.compare(DateTime.utc_now(), deadline) == :lt do
      case Vision.Native.visible(Image.end_of_match_icon()) do
        {:ok, _} ->
          :ok

        {:error, :not_found} ->
          # Sleep for a bit just so the Pi isn't busy-waiting.
          # This will keep the Pi cooler.
          Process.sleep(:timer.seconds(3))
          watch_match(deadline)

        {:error, reason} ->
          throw("Failed to watch match: #{inspect(reason)}")
      end
    else
      Logger.error("Match timed out")
      {:error, :timeout}
    end
  end

  defp check_ready_to_fight() do
    with :ok <- check_not_visible(Image.cpu()),
         :ok <- check_not_visible(Image.p1()),
         :ok <- check_not_visible(Image.scan_nfc()),
         :ok <- check_visible(Image.ready_to_fight()) do
      :ok
    else
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp check_visible(image) do
    case Vision.Native.visible(image) do
      {:ok, %{}} ->
        :ok

      {:error, :not_found} ->
        name = Path.basename(image)
        {:error, "#{name} not found"}

      error ->
        error
    end
  end

  defp check_not_visible(image) do
    case Vision.Native.visible(image) do
      {:error, :not_found} ->
        :ok

      {:ok, %{}} ->
        name = Path.basename(image)
        {:error, "#{name} found"}

      error ->
        error
    end
  end

  defp best_of_n_scores(best_of) do
    {:ok, loser} =
      Vision.Native.count_crop(
        Image.best_of_n_win(),
        %{left: 213, top: 307, right: 267, bottom: 337},
        confidence: 0.84
      )

    max = ceil(best_of / 2)

    {max - loser, loser}
  end

  defp determine_winner() do
    case Vision.Native.visible(Image.winner_icon()) do
      {:error, :not_found} ->
        throw("Winner not found")

      {:ok, %{x1: x, frame_width: w}} when x / w < 0.5 ->
        Logger.info("P1 Wins")
        {1, 0}

      {:ok, %{x1: _}} ->
        Logger.info("P2 Wins")
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
