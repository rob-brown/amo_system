defmodule TournamentRunner.MatchRunner do
  require Logger

  alias TournamentRunner.Image
  alias TournamentRunner.Script

  @match_duration :timer.seconds(450)

  @doc """
  Runs a match with the given amiibo and reports the scores using the given 
  function. Only supports Bo1 right now. Assumes the game is on the fighter
  screen.
  """
  def run(players, fun, retry_count \\ 2)

  def run(_, fun, 0) when is_function(fun, 2) do
    Logger.error("Retries exhausted")
    fun.(:skip, :skip)
  end

  def run({fp1, fp2}, fun, retry_count)
      when is_binary(fp1) and is_binary(fp2) and is_function(fun, 2) do
    try do
      {:ok, amiibo_count} = Vision.count(Image.fp())
      previous_amiibo? = amiibo_count > 0

      if previous_amiibo? do
        Script.load_subsequent_1v1(bindings: [amiibo1: fp1, amiibo2: fp2])
      else
        Script.load_initial_1v1(bindings: [amiibo1: fp1, amiibo2: fp2])
      end

      unless ready_to_fight?() do
        throw("Failed to prepare match")
      end

      # Start the match
      Joycontrol.command("plus")

      watch_match()

      Script.advance_to_scores()

      scores = determine_winner()

      report_scores(scores, fun)

      Script.after_match()
    catch
      <<error::binary>> ->
        Logger.error(error)
        Joycontrol.clear_amiibo()
        Script.close_game()
        Script.launch_ssbu_to_smash_menu()
        run({fp1, fp2}, fun, retry_count - 1)
    end
  end

  ## Helpers

  defp watch_match() do
    Vision.wait_until_found(Image.end_of_match_icon(), @match_duration, timeout: @match_duration)
  end

  defp ready_to_fight?() do
    with {:ok, nil} <- Vision.visible(Image.cpu()),
         {:ok, nil} <- Vision.visible(Image.p1()),
         {:ok, nil} <- Vision.visible(Image.scan_nfc()),
         {:ok, %{}} <- Vision.visible(Image.ready_to_fight()) do
      true
    else
      _ ->
        false
    end
  end

  defp determine_winner() do
    case Vision.visible(Image.winner_icon()) do
      {:ok, nil} ->
        throw("Winner not found")

      {:ok, %{x1: x, width: w}} when x / w < 0.5 ->
        Logger.info("P1 Wins")
        {1, 0}

      {:ok, %{x1: _}} ->
        Logger.info("P2 Wins")
        {0, 1}
    end
  end

  defp report_scores({fp1_score, fp2_score}, fun) do
    fun.(fp1_score, fp2_score)
  end
end
