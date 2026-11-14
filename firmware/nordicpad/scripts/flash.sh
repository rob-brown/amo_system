#!/bin/sh
set -e

NORDICPAD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FIRMWARE="$NORDICPAD_DIR/build/firmware/nordicpad.uf2"
SERIAL_DEVICE="${PICO_SERIAL:-/dev/cu.usbmodem4101}"
BOOTSEL_VOLUME="/Volumes/RP2350"
WAIT_SECONDS=15

wait_for() {
    waited=0
    while ! eval "$1"; do
        waited=$((waited + 1))
        if [ "$waited" -gt $((WAIT_SECONDS * 4)) ]; then
            echo "Timed out waiting for: $2"
            exit 1
        fi
        sleep 0.25
    done
}

if [ ! -d "$BOOTSEL_VOLUME" ]; then
    echo "Rebooting $SERIAL_DEVICE into BOOTSEL"
    stty -f "$SERIAL_DEVICE" 1200 || true
    wait_for "[ -d $BOOTSEL_VOLUME ]" "$BOOTSEL_VOLUME to mount"
fi

cp "$FIRMWARE" "$BOOTSEL_VOLUME/"
echo "Flashed $FIRMWARE"

wait_for "[ -e $SERIAL_DEVICE ]" "$SERIAL_DEVICE to return"
echo "Pico is back on $SERIAL_DEVICE"
