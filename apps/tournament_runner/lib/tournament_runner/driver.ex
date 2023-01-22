defmodule TournamentRunner.Driver do
  @callback save_file_name(TournamentRunner.Storage.t()) :: binary()

  @callback run(TournamentRunner.Storage.t()) :: :ok
end
