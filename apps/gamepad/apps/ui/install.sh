#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Expected one argument with the platform (joybonnet or ammobox)"
    exit 2
fi

PLATFORM=$1
URL="https://github.com/rob-brown/amo_system/releases/latest/download/gamepad.tar.gz"
DATABASE=/home/pi/amiibo.sqlite

echo Downloading latest gamepad release
mkdir -p ~/gamepad
curl --location $URL > ~/gamepad/gamepad.tar.gz

echo Uncompressing release files
tar -xzf ~/gamepad/gamepad.tar.gz -C ~/gamepad

echo Installing startup script
echo "@reboot /usr/bin/env PHX_HOST=ammobox.local PORT=4000 DB_PATH=$DATABASE PLATFORM=$PLATFORM SECRET_KEY_BASE=frgvEBs7NY74auQ8ziMVeEIB8XUOYKFs7PfNfpns+1CA3+e+DH5nUHGq1UExr3DH /home/pi/gamepad/bin/gamepad daemon" | sudo tee /etc/cron.d/gamepad >> /dev/null

echo Setting up database
env MIX_ENV=prod DB_PATH=$DATABASE SECRET_KEY_BASE=ignore /home/pi/gamepad/bin/gamepad eval "Ui.Release.migrate"

echo Reboot your Raspberry Pi to start the gamepad
