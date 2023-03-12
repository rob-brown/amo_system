#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Expected one argument with the platform (joybonnet or ammobox)"
    exit 2
fi

sudo killall pigpiod
sudo env PLATFORM=$1 MIX_ENV=prod PHX_SERVER=true SECRET_KEY_BASE=frgvEBs7NY74auQ8ziMVeEIB8XUOYKFs7PfNfpns+1CA3+e+DH5nUHGq1UExr3DH PHX_HOST=ammobox.local DB_PATH=/home/pi/amiibo.sqlite /home/pi/amiibo_system/apps/gamepad/apps/ui/_build/prod/rel/ui/bin/server
