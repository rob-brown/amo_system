#!/bin/sh
set -e

export PICO_SDK_PATH="${PICO_SDK_PATH:-$HOME/code/pico-sdk}"
export PATH="/opt/arm-gnu-toolchain/bin:$PATH"

NORDICPAD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$NORDICPAD_DIR/build/firmware"

cmake -S "$NORDICPAD_DIR" -B "$BUILD_DIR" "$@"
cmake --build "$BUILD_DIR" -j4

echo "Firmware: $BUILD_DIR/nordicpad.uf2"
