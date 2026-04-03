defmodule Bracket.Render.SVGTest do
  use ExUnit.Case

  alias Bracket

  defp tournament_4p do
    ~w[Alice Bob Charlie Dave]
    |> Enum.reduce(Bracket.new("Test Event", :single_elimination), fn name, t ->
      Bracket.add_participant(t, name)
    end)
    |> Bracket.start!()
  end

  defp tournament_4p_played do
    play_all(tournament_4p())
  end

  describe "to_svg/1 for elimination bracket" do
    test "produces valid SVG with required elements" do
      svg = Bracket.to_svg(tournament_4p())

      assert svg =~ "<svg"
      assert svg =~ "</svg>"
      assert svg =~ ~r/width="\d+"/
      assert svg =~ ~r/height="\d+"/
      assert svg =~ "xmlns=\"http://www.w3.org/2000/svg\""
    end

    test "contains participant names" do
      svg = Bracket.to_svg(tournament_4p())

      assert svg =~ "Alice"
      assert svg =~ "Bob"
      assert svg =~ "Charlie"
      assert svg =~ "Dave"
    end

    test "contains round labels" do
      svg = Bracket.to_svg(tournament_4p())

      assert svg =~ "Final"
    end

    test "highlights winner boxes after match completion" do
      t = tournament_4p()
      [first_id | _] = List.first(t.rounds)
      {:ok, t} = Bracket.report_score(t, first_id, 3, 0)

      svg = Bracket.to_svg(t)

      # Winner fill color should appear
      assert svg =~ "#D4EDDA"
    end

    test "accepts custom colors" do
      svg = Bracket.to_svg(tournament_4p(), background: "#000000", match_fill: "#1A1A2E")

      assert svg =~ ~s(fill="#000000")
      assert svg =~ "#1A1A2E"
    end

    test "SVG dimensions scale with bracket size" do
      t4 = tournament_4p()

      t8 =
        ~w[A B C D E F G H]
        |> Enum.reduce(Bracket.new("Big", :single_elimination), &Bracket.add_participant(&2, &1))
        |> Bracket.start!()

      svg4 = Bracket.to_svg(t4)
      svg8 = Bracket.to_svg(t8)

      width4 = extract_attr(svg4, "width")
      height4 = extract_attr(svg4, "height")
      width8 = extract_attr(svg8, "width")
      height8 = extract_attr(svg8, "height")

      # 8-player bracket should be wider (more rounds) and taller (more matches)
      assert width8 > width4
      assert height8 > height4
    end

    test "connector lines are rendered" do
      svg = Bracket.to_svg(tournament_4p())

      # Connector lines use <line> elements
      assert svg =~ "<line"
    end
  end

  describe "to_svg/1 for standings formats" do
    test "round robin produces table with standings" do
      t =
        ~w[A B C D]
        |> Enum.reduce(Bracket.new("RR Test", :round_robin), &Bracket.add_participant(&2, &1))
        |> Bracket.start!()

      svg = Bracket.to_svg(t)

      assert svg =~ "<svg"
      assert svg =~ "Name"
    end
  end

  describe "to_svg/1 complete bracket" do
    test "completed bracket SVG still valid" do
      svg = Bracket.to_svg(tournament_4p_played())

      assert svg =~ "<svg"
      assert svg =~ "</svg>"
    end
  end

  describe "to_png/1" do
    test "returns :vix_not_available when vix not installed" do
      # In test environment without vix, expect this error
      # If vix IS installed, this test should pass too (returns {:ok, binary})
      result = Bracket.to_png(tournament_4p())

      case result do
        {:ok, png} ->
          assert is_binary(png)
          # PNG magic bytes
          assert binary_part(png, 0, 4) == <<137, 80, 78, 71>>

        {:error, :vix_not_available} ->
          assert true
      end
    end
  end

  defp play_all(tournament) do
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

      play_all(tournament)
    end
  end

  defp extract_attr(svg, attr) do
    case Regex.run(~r/#{attr}="(\d+)"/, svg) do
      [_, val] -> String.to_integer(val)
      _ -> 0
    end
  end
end
