#!/bin/bash

VERSION=$(cat "VERSION")

echo Building Rabbit Driver v$VERSION

mix deps.get --only prod
env MIX_ENV=prod mix compile
env MIX_ENV=prod mix release --overwrite
cp _build/prod/rabbit_driver-$VERSION.tar.gz ./rabbit_driver-$VERSION.tar.gz
