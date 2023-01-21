defmodule SubmissionInfo.EntriesParser do
  alias SubmissionInfo.Team

  def parse_tsv(path) do
    path
    |> Path.expand()
    |> File.read!()
    |> String.split("\n", trim: true)
    |> Enum.drop(1)
    |> Enum.map(&process_line/1)
  end

  defp process_line(line) do
    line
    |> String.split("\t")
    |> then(fn [
                 _date,
                 trainer,
                 contact,
                 team_name,
                 amiibo1_name,
                 amiibo1_character,
                 amiibo2_name,
                 amiibo2_character,
                 amiibo3_name,
                 amiibo3_character,
                 _notes
               ] ->
      %Team{
        trainer: trainer,
        contact: contact,
        team_name: team_name,
        amiibo: [
          %{name: amiibo1_name, character: amiibo1_character},
          %{name: amiibo2_name, character: amiibo2_character},
          %{name: amiibo3_name, character: amiibo3_character}
        ]
      }
    end)
  end
end
