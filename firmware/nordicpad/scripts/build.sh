#!/bin/sh
set -e

NORDICPAD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
NCS_VERSION="${NCS_VERSION:-v2.9.3}"
NCS_ROOT="${NCS_ROOT:-/opt/nordic/ncs/$NCS_VERSION}"
BUILD_DIR="${NORDICPAD_DONGLE_BUILD_DIR:-$NORDICPAD_DIR/build/dongle-app}"
APP_VERSION="${APP_VERSION:-$(date +%s)}"
INTERVAL_PATCH="$NORDICPAD_DIR/dongle/zephyr_conn_interval_min.patch"
PACKAGE="$BUILD_DIR/dongle-nordicpad.zip"

if ! patch -p1 -R --dry-run -s -d "$NCS_ROOT/zephyr" < "$INTERVAL_PATCH" > /dev/null 2>&1; then
    echo "The connection interval patch is not applied to $NCS_ROOT/zephyr. Apply it with:"
    echo "  patch -p1 -d $NCS_ROOT/zephyr < $INTERVAL_PATCH"
    exit 1
fi

nrfutil sdk-manager toolchain launch --ncs-version "$NCS_VERSION" --chdir "$NCS_ROOT/zephyr" -- \
    west build -b nrf52840dongle/nrf52840 -d "$BUILD_DIR" "$@" "$NORDICPAD_DIR/dongle_app"

nrfutil nrf5sdk-tools pkg generate --hw-version 52 --sd-req 0x00 \
    --application "$BUILD_DIR/dongle_app/zephyr/zephyr.hex" \
    --application-version "$APP_VERSION" "$PACKAGE" > /dev/null

echo "Package: $PACKAGE (application version $APP_VERSION)"
