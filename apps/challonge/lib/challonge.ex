defmodule Challonge do
  require Logger

  alias Challonge.Tournament
  alias Challonge.Match
  alias Challonge.Participant
  alias Challonge.Score

  @spec retry((() -> result), non_neg_integer()) :: result
        when result: any() | {:error, any()} | :error
  def retry(fun, retries \\ 3) when is_function(fun, 0) and retries >= 0 do
    case {fun.(), retries} do
      {result, 0} ->
        result

      {error = {:error, _}, _} ->
        Logger.warn("Challonge failed #{inspect(error)}")
        retry(fun, retries - 1)

      {:error, _} ->
        Logger.warn("Challonge failed")
        retry(fun, retries - 1)

      {other, _} ->
        other
    end
  end

  @spec get_tournament(integer() | binary()) :: {:ok, Tournament.t()} | {:error, any()}
  def get_tournament(id) when id != nil do
    url = "https://api.challonge.com/v1/tournaments/#{id}.json?api_key=#{api_key()}"

    get(url, &Tournament.parse/1)
  end

  @spec create_tournament(binary(), keyword()) :: {:ok, Tournament.t()} | {:error, any()}
  def create_tournament(name, options \\ []) do
    url = "https://api.challonge.com/v1/tournaments.json"

    payload = %{
      api_key: api_key(),
      name: name,
      description: Keyword.get(options, :description, ""),
      tournament_type: Keyword.get(options, :type, "single elimination")
    }

    post(url, payload, &Tournament.parse/1)
  end

  @spec add_participants(Tournament.t(), [binary()] | %{name: binary()}) :: :ok | {:error, any()}
  def add_participants(%Tournament{id: id}, participants) do
    participants = Enum.map(participants, &coerce_participant/1)
    url = "https://api.challonge.com/v1/tournaments/#{id}/participants/bulk_add.json"

    payload = %{
      api_key: api_key(),
      participants: participants
    }

    post(url, payload)
  end

  @spec start_tournament(Tournament.t()) :: :ok | {:error, any()}
  def start_tournament(%Tournament{id: id}) do
    url = "https://api.challonge.com/v1/tournaments/#{id}/start.json"
    post(url, %{api_key: api_key()})
  end

  @spec list_participants(Tournament.t()) :: [Participant.t()] | {:error, any()}
  def list_participants(%Tournament{id: id}) do
    url = "https://api.challonge.com/v1/tournaments/#{id}/participants.json?api_key=#{api_key()}"

    get(
      url,
      &Enum.map(&1, fn x ->
        {:ok, m} = Participant.parse(x)
        m
      end)
    )
  end

  @spec list_matches(Tournament.t()) :: [Match.t()] | {:error, any()}
  def list_matches(%Tournament{id: id}) do
    url = "https://api.challonge.com/v1/tournaments/#{id}/matches.json?api_key=#{api_key()}"

    get(
      url,
      &Enum.map(&1, fn x ->
        {:ok, m} = Match.parse(x)
        m
      end)
    )
  end

  @spec post_results(Tournament.t(), Match.t(), Score.t()) :: Match.t() | {:error, any()}
  def post_results(tournament = %Tournament{}, match = %Match{}, score = %Score{}) do
    url = "https://api.challonge.com/v1/tournaments/#{tournament.id}/matches/#{match.id}.json"

    winner_id =
      case Score.winner(score) do
        :p1 -> match.p1_id
        :p2 -> match.p2_id
        _ -> nil
      end

    payload = %{
      api_key: api_key(),
      match: %{
        scores_csv: Score.to_csv(score),
        winner_id: winner_id
      }
    }

    put(url, payload, fn x ->
      {:ok, m} = Match.parse(x)
      m
    end)
  end

  def next_match(tournament) do
    tournament
    |> list_matches()
    |> Enum.find(&(&1.winner_id == nil and &1.p1_id != nil and &1.p2_id != nil))
  end

  ## Helpers

  defp api_key() do
    Application.get_env(:challonge, :challonge_api_key) || raise "No Challonge API key"
  end

  defp coerce_participant(name) when is_binary(name) do
    %{name: name}
  end

  defp coerce_participant(map = %{name: _}) do
    map
  end

  defp get(url, fun) do
    request(:get, url, "", fun)
  end

  defp put(url, payload, fun) do
    request(:put, url, payload, fun)
  end

  defp post(url, payload) do
    post(url, payload, fn _ -> :ok end)
  end

  defp post(url, payload, fun) do
    request(:post, url, payload, fun)
  end

  @spec request(method :: atom(), url :: binary(), payload :: binary(), (map() -> result)) ::
          result | {:error, any()}
        when result: any()
  defp request(method, url, payload, fun) when is_function(fun, 1) do
    json = Jason.encode!(payload)
    headers = [{"Content-Type", "application/json"}]
    options = [timeout: :timer.seconds(20)]

    method
    |> HTTPoison.request(url, json, headers, options)
    |> case do
      {:ok, %HTTPoison.Response{status_code: 200, body: body}} ->
        body
        |> Jason.decode!()
        |> fun.()

      {:ok, %HTTPoison.Response{status_code: code, body: body}} ->
        {:error, {:http, code, body}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
