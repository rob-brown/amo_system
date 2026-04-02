defmodule Bracket.Serialization.TOMLTest do
  use ExUnit.Case

  alias Bracket

  defp create_started_tournament do
    ~w[Alice Bob Charlie Dave]
    |> Enum.reduce(Bracket.new("Test Tournament", :single_elimination), fn name, t ->
      Bracket.add_participant(t, name)
    end)
    |> Bracket.start!()
  end

  describe "encode/decode round-trip" do
    test "pending tournament round-trips" do
      # Arrange
      tournament = Bracket.new("My Tournament", :single_elimination)
      tournament = Bracket.add_participant(tournament, "Alice")
      tournament = Bracket.add_participant(tournament, "Bob")

      # Act
      toml = Bracket.to_toml(tournament)
      {:ok, decoded} = Bracket.from_toml(toml)

      # Assert
      assert decoded.name == tournament.name
      assert decoded.format == tournament.format
      assert decoded.status == tournament.status
      assert length(decoded.participants) == 2
    end

    test "started tournament with matches round-trips" do
      # Arrange
      tournament = create_started_tournament()

      # Act
      toml = Bracket.to_toml(tournament)
      {:ok, decoded} = Bracket.from_toml(toml)

      # Assert
      assert decoded.id == tournament.id
      assert map_size(decoded.matches) == map_size(tournament.matches)
      assert decoded.rounds == tournament.rounds
      assert decoded.seeding == tournament.seeding
    end

    test "match statuses survive round-trip" do
      # Arrange
      tournament = create_started_tournament()
      [first_id | _] = List.first(tournament.rounds)
      {:ok, tournament} = Bracket.report_score(tournament, first_id, 3, 1)

      # Act
      toml = Bracket.to_toml(tournament)
      {:ok, decoded} = Bracket.from_toml(toml)

      # Assert
      original_match = tournament.matches[first_id]
      decoded_match = decoded.matches[first_id]

      assert decoded_match.status == :complete
      assert decoded_match.winner_id == original_match.winner_id
      assert decoded_match.score.sets == original_match.score.sets
    end

    test "config survives round-trip" do
      # Arrange
      tournament =
        Bracket.new("Test", :single_elimination, config: [best_of: 3, third_place_match: true])

      tournament = Bracket.add_participant(tournament, "A")
      tournament = Bracket.add_participant(tournament, "B")

      # Act
      toml = Bracket.to_toml(tournament)
      {:ok, decoded} = Bracket.from_toml(toml)

      # Assert
      assert decoded.config.best_of == 3
      assert decoded.config.third_place_match == true
    end

    test "winner_feeds survive round-trip" do
      # Arrange
      tournament = create_started_tournament()

      # Act
      toml = Bracket.to_toml(tournament)
      {:ok, decoded} = Bracket.from_toml(toml)

      # Assert
      Enum.each(tournament.matches, fn {id, match} ->
        decoded_match = decoded.matches[id]
        assert decoded_match.winner_feeds == match.winner_feeds
        assert decoded_match.loser_feeds == match.loser_feeds
      end)
    end
  end

  describe "from_toml/1 error cases" do
    test "returns error for invalid TOML" do
      assert {:error, _} = Bracket.from_toml("this is not [valid toml")
    end

    test "returns error for missing required fields" do
      toml = """
      name = "Missing format"
      """

      assert {:error, _} = Bracket.from_toml(toml)
    end
  end

  describe "TOML output format" do
    test "produces valid TOML with no tournament wrapper key" do
      # Arrange
      tournament = Bracket.new("My Event", :single_elimination)

      # Act
      toml = Bracket.to_toml(tournament)

      # Assert: top-level keys exist without nesting
      assert toml =~ ~r/^name = /m
      assert toml =~ ~r/^format = /m
      refute toml =~ "[tournament]"
    end
  end
end
