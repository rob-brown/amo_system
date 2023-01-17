defmodule TournamentRunner.Image do
  @image_dir :code.priv_dir(:tournament_runner) |> Path.join("images")
  @external_resource @image_dir

  for t <- File.ls!(@image_dir) do
    path = Path.join(@image_dir, t)
    @external_resource path

    def unquote(:"#{Path.rootname(t)}")() do
      unquote(path)
    end
  end
end
