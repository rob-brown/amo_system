#!/bin/bash

# From: https://hexdocs.pm/phoenix/releases.html

mix deps.get --only prod
env MIX_ENV=prod mix compile
env MIX_ENV=prod SECRET_KEY_BASE="UNUSED" DB_PATH="/home/pi/amiibo.sqlite" mix ecto.create -r AmiiboManager.Repo
env MIX_ENV=prod SECRET_KEY_BASE="UNUSED" DB_PATH="/home/pi/amiibo.sqlite" mix ecto.migrate -r AmiiboManager.Repo
env MIX_ENV=prod mix assets.deploy
env MIX_ENV=prod mix release --overwrite
