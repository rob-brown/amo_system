#!/bin/sh
set -e

NORDICPAD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="${NORDICPAD_DONGLE_PACKAGE:-$NORDICPAD_DIR/build/dongle-app/dongle-nordicpad.zip}"
APP_PRODUCT="nordicpad dongle"
DFU_PRODUCT="Open DFU Bootloader"
HOST_CHANNEL_VCOM=1
REBOOT_TO_BOOTLOADER='\002\005\004\362\001\167\000'
WAIT_SECONDS=20

serial_of() {
    nrfutil device list | awk -v product="$1" '
        /^[0-9A-Fa-f]+$/ { serial = $1 }
        /^Product/ {
            name = $0
            sub(/^Product[ \t]+/, "", name)
            if (name == product) print serial
        }'
}

host_port_of() {
    nrfutil device list | awk -v serial="$1" -v vcom="$HOST_CHANNEL_VCOM" '
        /^[0-9A-Fa-f]+$/ { current = $1 }
        current == serial && $0 ~ ("vcom: " vcom "$") {
            port = ($1 == "Ports") ? $2 : $1
            sub(/,$/, "", port)
            sub(/^\/dev\/tty\./, "/dev/cu.", port)
            print port
        }'
}

wait_for_serial() {
    waited=0
    while [ -z "$(serial_of "$1")" ]; do
        waited=$((waited + 1))
        if [ "$waited" -gt "$WAIT_SECONDS" ]; then
            echo "Timed out waiting for: $1"
            exit 1
        fi
        sleep 1
    done
}

program() {
    nrfutil device program --serial-number "$1" --firmware "$PACKAGE" --traits nordicDfu
}

if [ ! -f "$PACKAGE" ]; then
    echo "No package at $PACKAGE; run scripts/build.sh first"
    exit 1
fi

dfu_serial="${NORDICPAD_DFU_SERIAL:-$(serial_of "$DFU_PRODUCT")}"

if [ -z "$dfu_serial" ]; then
    app_serial="$(serial_of "$APP_PRODUCT")"
    if [ -z "$app_serial" ]; then
        echo "No $APP_PRODUCT or $DFU_PRODUCT found"
        exit 1
    fi

    port="$(host_port_of "$app_serial")"
    echo "Rebooting $app_serial into the bootloader through $port"
    stty -f "$port" raw
    printf "$REBOOT_TO_BOOTLOADER" > "$port"
    wait_for_serial "$DFU_PRODUCT"
    dfu_serial="$(serial_of "$DFU_PRODUCT")"
fi

if [ "$(echo "$dfu_serial" | wc -w | tr -d ' ')" -gt 1 ]; then
    echo "More than one bootloader device is attached; set NORDICPAD_DFU_SERIAL to one of: $dfu_serial"
    exit 1
fi

echo "Flashing $PACKAGE to $dfu_serial"
program "$dfu_serial" || program "$dfu_serial"

wait_for_serial "$APP_PRODUCT"
echo "The dongle is back as $(serial_of "$APP_PRODUCT")"
