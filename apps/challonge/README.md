# Challonge

This package is for interfacing with the Challonge API. Though this library is usable outside of automation,
it's useful for automating tournaments. Challonge can be used to store the matches and report the results.
This avoids needing to implement the logic for organizing tournament brackets.

The Challonge API is extremely flaky. It's strongly recommended to cache your data and retry requests.
Otherwise, your automated tournament runner may stop working when Challonge has some service issues.

You will need to set a Challonge API key. The easiest way to do this is to create a `config/runtime.exs`
file like this:

```elixir
import Config 

config :weapon_ex,
  challonge_api_key: System.get_env("CHALLONGE_API_KEY")
```

Then you just need to set the `CHALLONGE_API_KEY` env variable.
