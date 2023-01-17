defmodule TournamentRunner.Script do
  @script_dir :code.priv_dir(:tournament_runner) |> Path.join("scripts")
  @external_resource @script_dir

  for s <- File.ls!(@script_dir), String.ends_with?(s, ".lua") do
    name = Path.rootname(s)
    path = Path.join(@script_dir, s)
    @external_resource path

    def unquote(:"#{name}")(opts \\ []) do
      Autopilot.LuaScript.run_file(unquote(path), opts)
    end
  end
end
