#!/bin/bash

URL="https://github.com/rob-brown/amo_system/releases/latest/download/rabbit_driver.tar.gz"

echo Downloading latest rabbit driver release
mkdir -p ~/rabbit_driver
curl --location $URL > ~/rabbit_driver/rabbit_driver.tar.gz

echo Uncompressing release files
tar -xzf ~/rabbit_driver/rabbit_driver.tar.gz -C ~/rabbit_driver

echo Installing startup script
echo "@reboot pi /usr/bin/env /home/pi/rabbit_driver/bin/rabbit_driver start_iex" | sudo tee /etc/cron.d/rabbit_driver >> /dev/null

echo Reboot your Raspberry Pi to start the rabbit driver
