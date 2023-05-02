#!/bin/bash

VERSION=$(cat "VERSION")

echo Building Tournament Runner v$VERSION

mix deps.get --only prod
env MIX_ENV=prod mix compile
env MIX_ENV=prod mix release --overwrite
cp _build/prod/tournament_runner-$VERSION.tar.gz ./tournament_runner-$VERSION.tar.gz
