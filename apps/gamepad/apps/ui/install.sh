#!/bin/bash

if [[ $# -ne 1 ]]; then
    echo "Expected one argument with the platform (joybonnet or ammobox)"
    exit 2
fi

PLATFORM=$1
URL="https://github.com/rob-brown/amiibo_system/releases/latest/download/gamepad.tar.gz"

echo Downloading latest gamepad release
mkdir -p ~/gamepad
curl --location $URL > ~/gamepad/gamepad.tar.gz

echo Uncompressing release files
tar -xzf ~/gamepad/gamepad.tar.gz -C ~/gamepad

# Update crontab so the code starts on boot
echo Installing startup script
echo "@reboot /usr/bin/env PLATFORM=$PLATFORM SECRET_KEY_BASE=frgvEBs7NY74auQ8ziMVeEIB8XUOYKFs7PfNfpns+1CA3+e+DH5nUHGq1UExr3DH /home/pi/gamepad/bin/gamepad daemon" | sudo tee /etc/cron.d/gamepad >> /dev/null

echo Reboot your Raspberry Pi to start the gamepad
