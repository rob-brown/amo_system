defmodule SubmissionInfo do
  def binary_for_amiibo(amiibo, trainer_name, bin_dir) do
    trainer_name
    |> filename(amiibo.character, amiibo.name)
    |> Path.expand(bin_dir)
    |> File.read!()
  end

  def filename(trainer, character, nickname) do
    [trainer, character, nickname]
    |> Enum.map(&(&1 |> String.trim() |> sanitize_for_fs()))
    |> Enum.join("-")
    |> then(&(&1 <> ".bin"))
  end

  def sanitize_for_fs(text, replacement \\ "+") do
    String.replace(text, ~r{\\|/|<|>|:|"|'|\?|\*|\||_}, replacement)
  end
end
