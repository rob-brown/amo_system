#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Expected one argument with your Challonge API key"
    exit 2
fi

CHALLONGE_API_KEY=$1
URL="https://github.com/rob-brown/amo_system/releases/latest/download/tournament_runner.tar.gz"

echo Downloading latest tournament runner release
mkdir -p ~/tournament_runner
curl --location $URL > ~/tournament_runner/tournament_runner.tar.gz

echo Uncompressing release files
tar -xzf ~/tournament_runner/tournament_runner.tar.gz -C ~/tournament_runner

echo Installing startup script
echo "@reboot pi /usr/bin/env CHALLONGE_API_KEY=$CHALLONGE_API_KEY /home/pi/tournament_runner/bin/tournament_runner start" | sudo tee /etc/cron.d/tournament_runner >> /dev/null

echo Reboot your Raspberry Pi to start the tournament runner
