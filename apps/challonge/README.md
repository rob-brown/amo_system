# Challonge

This package is for interfacing with the Challonge API. Though this library is usable outside of automation,
it's useful for automating tournaments. Challonge can be used to store the matches and report the results.
This avoids needing to implement the logic for organizing tournament brackets.

The Challonge API is extremely flaky. It's strongly recommended to cache your data and retry requests.
Otherwise, your automated tournament runner may stop working when Challonge has some service issues.
