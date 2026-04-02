defmodule Bracket.Format.DoubleEliminationTest do
  use ExUnit.Case

  alias Bracket

  defp build_and_start(names, opts \\ []) do
    names
    |> Enum.reduce(Bracket.new("Test", :double_elimination, opts), fn name, t ->
      Bracket.add_participant(t, name)
    end)
    |> Bracket.start!()
  end

  describe "generate_matches/1" do
    test "grand finals match always exists" do
      tournament = build_and_start(~w[A B C D])

      assert Map.has_key?(tournament.matches, "gf")
    end

    test "double elimination has more matches than single elimination" do
      de_tournament = build_and_start(~w[A B C D])

      se_tournament =
        ~w[A B C D]
        |> Enum.reduce(Bracket.new("Test", :single_elimination), fn name, t ->
          Bracket.add_participant(t, name)
        end)
        |> Bracket.start!()

      assert map_size(de_tournament.matches) > map_size(se_tournament.matches)
    end

    test "2 players: has winners bracket match and grand finals" do
      tournament = build_and_start(~w[Alice Bob])

      assert map_size(tournament.matches) >= 2
      assert Map.has_key?(tournament.matches, "gf")
    end

    test "starts with ready matches" do
      tournament = build_and_start(~w[A B C D])

      ready = tournament.matches |> Map.values() |> Enum.count(&(&1.status == :ready))
      assert ready > 0
    end
  end

  describe "complete?" do
    test "not complete before any matches" do
      tournament = build_and_start(~w[A B])
      refute Bracket.complete?(tournament)
    end

    test "complete after grand finals" do
      # Arrange
      tournament = build_and_start(~w[A B])

      # Act — play through all matches
      tournament = play_all_matches(tournament)

      # Assert
      assert Bracket.complete?(tournament)
    end
  end

  defp play_all_matches(tournament) do
    ready = Bracket.next_matches(tournament)

    if ready == [] do
      tournament
    else
      tournament =
        Enum.reduce(ready, tournament, fn match, t ->
          case Bracket.report_score(t, match.id, 3, 0) do
            {:ok, t2} -> t2
            _ -> t
          end
        end)

      play_all_matches(tournament)
    end
  end
end
