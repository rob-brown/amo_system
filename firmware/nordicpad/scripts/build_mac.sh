#!/bin/sh
set -e

NORDICPAD_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$NORDICPAD_DIR/build/mac"

cmake -S "$NORDICPAD_DIR/mac" -B "$BUILD_DIR" "$@"
cmake --build "$BUILD_DIR" -j4

echo "Mac build: $BUILD_DIR/nordicpad_mac"
