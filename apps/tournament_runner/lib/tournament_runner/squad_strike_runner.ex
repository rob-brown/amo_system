defmodule TournamentRunner.SquadStrikeRunner do
  require Logger

  alias TournamentRunner.Image
  alias TournamentRunner.Script

  @match_duration :timer.minutes(8)

  def run(players, fun, retry_count \\ 3)

  def run(_, fun, 0) when is_function(fun, 2) do
    Logger.error("Retries exhausted")
    fun.(:skip, :skip)
  end

  def run({[fp1, fp2, fp3], [fp4, fp5, fp6]}, fun, retry_count) when is_function(fun, 2) do
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
      report_scores(scores, fun)

      Script.squad_after_match()
    catch
      "" <> error ->
        Logger.error(error)
        Joycontrol.clear_amiibo()
        Script.close_game()
        Script.launch_ssbu_to_squad_strike()
        run({[fp1, fp2, fp3], [fp4, fp5, fp6]}, fun, retry_count - 1)
    end
  end

  ## Helpers

  defp watch_match() do
    Vision.wait_until_found(Image.squad_victory(), @match_duration, timeout: @match_duration)
  end

  defp ready_to_fight?() do
    Vision.count(Image.squad_fp()) == {:ok, 6}
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

  defp report_scores({team1_score, team2_score}, fun) do
    fun.(team1_score, team2_score)
  end
end
