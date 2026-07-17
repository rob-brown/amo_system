# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`bracket` is a standalone Elixir library + escript CLI for creating and running tournament brackets (single elimination, double elimination, round robin, Swiss). It stores tournament state as TOML on disk, mutates it through pure functional transitions, and can render the current state as ASCII, SVG, or PNG. It is part of the `bracket` monorepo but has no dependency on the other AMO System apps.

## Development Commands

```bash
mix deps.get              # install dependencies
mix test                  # run tests
mix test test/bracket/format/swiss_test.exs   # run a single test file
mix test test/bracket/format/swiss_test.exs:42 # run a single test by line
mix format                 # format code (required after any change)
mix escript.build          # build the `bracket` CLI executable
```

The compiled `bracket` escript can then be run directly, e.g. `./bracket new tournament.toml "My Event" --format double_elimination`. Run `./bracket help` for the full command list.

## Architecture

### State model

Everything revolves around `Bracket.Tournament`, an immutable struct holding `participants`, `matches` (a map keyed by match id), `rounds`, `seeding`, and a `Bracket.Config` (best-of, tiebreakers, Swiss options, etc). All state transitions go through `Bracket.Tournament` and return an updated struct — there is no process/GenServer, no database. Persistence is just serializing/deserializing this struct to/from TOML (`Bracket.Serialization.TOML`).

`Bracket` (`lib/bracket.ex`) is the public facade module — CLI and any external caller should go through it (`Bracket.new/3`, `Bracket.start/2`, `Bracket.report_score/3-4`, `Bracket.next_matches/1`, `Bracket.standings/1`, `Bracket.to_svg/2`, etc) rather than calling `Bracket.Tournament` or format modules directly.

### Format modules (pluggable bracket logic)

`Bracket.Format` defines a behaviour (`generate_matches/1`, `standings/1`, `complete?/1`) implemented by:
- `Bracket.Format.SingleElimination`
- `Bracket.Format.DoubleElimination`
- `Bracket.Format.RoundRobin`
- `Bracket.Format.Swiss`

`Bracket.Tournament.report_score/3` and `Bracket` dispatch to the correct module based on `tournament.format` via a private `format_module/1` mapping duplicated in both `Bracket` and `Bracket.Tournament` — when adding a new format, update both.

Match progression uses a wiring model: each `Bracket.Match` carries `winner_feeds`/`loser_feeds` (`{target_match_id, :p1 | :p2}` or `nil`), set up by the format module when it generates matches. `Tournament.report_score/3` completes a match, then walks `advance_match/2` to place the winner/loser into their next match's slot, auto-resolving byes (`bye_winner/1`) and re-checking `complete?/1` via the format module.

### Other core pieces

- `Bracket.Seeding` — standard, random, or rating-based seeding; `bracket_positions/1` computes canonical seed placement for elimination brackets (e.g. `[1, 4, 3, 2]` for a 4-bracket) so top seeds meet as late as possible.
- `Bracket.Score` / `Bracket.Standings` — set-based scoring and per-format standings/tiebreaker calculation.
- `Bracket.Render.ASCII` / `Bracket.Render.SVG` / `Bracket.Render.PNG` — three renderers for the same tournament state; PNG rendering depends on the optional `vix` dep and returns `{:error, :vix_not_available}` if it's not compiled in.
- `Bracket.Serialization.TOML` — the only persistence format; round-trips a `Tournament` struct to/from TOML text.
- `Bracket.CLI` (`lib/bracket/cli.ex`) — escript entry point (`main_module` in `mix.exs`). Each subcommand loads the tournament from TOML, calls into `Bracket`, and re-saves the file; it's a thin wrapper and should stay that way — put logic in the library, not the CLI.

### Adding a new tournament format

Implement the `Bracket.Format` behaviour, then register the module in both `format_module/1` private functions (`lib/bracket.ex` and `lib/bracket/tournament.ex`), and add the format atom to `Bracket.Tournament.format/0` typespec and `Bracket.CLI.parse_format/1`.
