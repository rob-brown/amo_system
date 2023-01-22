defmodule SubmissionInfo.AmiiboParser do
  alias SubmissionInfo.Amiibo

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
                 name,
                 character,
                 trainer,
                 attack,
                 defense,
                 type,
                 personality
                 | abilities
               ] ->
      %Amiibo{
        name: name,
        character: character,
        trainer: trainer,
        attack: String.to_integer(attack),
        defense: String.to_integer(defense),
        type: type,
        personality: personality,
        abilities: Enum.reject(abilities, &(&1 == "None"))
      }
    end)
  end
end
