# Bracket

A tournament bracket manager. Create a tournament, add participants, seed and
start it, report scores as matches are played, and export the current state
as ASCII, SVG, or PNG. Tournament state lives entirely in a single TOML file.

Supported formats: `single_elimination`, `double_elimination`, `round_robin`,
`swiss`.

## Building

Requires Elixir ~> 1.14.

```bash
mix deps.get
mix escript.build
```

This produces a `bracket` executable in the project directory. Run it
directly:

```bash
./bracket help
```

Optional: PNG export requires the `vix` dependency to be compiled in. It's
already listed in `mix.exs` as an optional dep, so `mix deps.get` followed by
`mix escript.build` is sufficient — if `vix` fails to compile, everything
else still works and PNG export will report `--type png` as unavailable.

## Usage

All commands operate on a `<file.toml>` tournament file, reading it in and
writing the updated state back out.

### Create a tournament

```bash
./bracket new tournament.toml "My Event" --format double_elimination --best-of 3
```

`--format` is required (`single_elimination`, `double_elimination`,
`round_robin`, or `swiss`). `--best-of` defaults to `1`.

### Add participants

```bash
./bracket add tournament.toml Alice Bob Charlie Dave
```

Participants can only be added while the tournament is pending (before
`start`).

### Start the tournament

```bash
./bracket start tournament.toml --seeding standard
```

Seeds participants and generates the first round of matches. `--seeding` is
`standard` (seed by add order) or `random`; defaults to `standard`.

### Report a match result

```bash
./bracket report tournament.toml --match <id> --score 3-1
```

Reports a single-set score for the given match id. Once a match is decided,
the winner (and loser, for double elimination) automatically advance to
their next match, including auto-resolving byes.

### Generate the next Swiss round

```bash
./bracket next-round tournament.toml
```

Swiss only — generates the next round's pairings once the current round is
complete.

### View bracket state

```bash
./bracket show tournament.toml        # ASCII art of the current bracket
./bracket matches tournament.toml     # list of matches ready to be played
./bracket standings tournament.toml   # current standings table
```

### Export an image

```bash
./bracket image tournament.toml --type svg
./bracket image tournament.toml --type png --output bracket.png
```

`--type` defaults to `svg`. `--output` defaults to the `.toml` path with the
extension swapped (e.g. `tournament.svg`).

### Reset

```bash
./bracket reset tournament.toml
```

Clears all matches and returns the tournament to its pending state,
keeping participants.

## Example TOML files

`sample_tournament.toml`, `sample_de.toml`, and `sample_swiss.toml` in this
directory are example tournament files you can inspect or run commands
against directly, e.g.:

```bash
./bracket show sample_de.toml
./bracket standings sample_swiss.toml
```
