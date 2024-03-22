#!/bin/bash

BIT_SIZE=$(getconf LONG_BIT)
URL="https://github.com/rob-brown/amo_system/releases/latest/download/proxy-$BIT_SIZE-bit.tar.gz"
DATABASE=/home/pi/amiibo.sqlite

echo Downloading latest proxy release
mkdir -p ~/proxy
curl --location $URL > ~/proxy/proxy.tar.gz

echo Uncompressing release files
tar -xzf ~/proxy/proxy.tar.gz -C ~/proxy

echo Installing startup script
echo "@reboot pi sudo /usr/bin/env PHX_SERVER=true PHX_HOST=ammobox.local PORT=4000 DB_PATH=$DATABASE SECRET_KEY_BASE=frgvEBs7NY74auQ8ziMVeEIB8XUOYKFs7PfNfpns+1CA3+e+DH5nUHGq1UExr3DH /home/pi/proxy/bin/proxy start" | sudo tee /etc/cron.d/proxy >> /dev/null

echo Setting up database
env MIX_ENV=prod DB_PATH=$DATABASE SECRET_KEY_BASE=ignore /home/pi/proxy/bin/proxy eval "Ui.Release.migrate"

echo Reboot your Raspberry Pi to start the proxy
