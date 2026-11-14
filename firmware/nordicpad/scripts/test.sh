#!/bin/sh
set -e

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${NORDICPAD_TEST_BUILD_DIR:-$ROOT/build/test}"

cmake -S "$ROOT/test" -B "$BUILD_DIR"
cmake --build "$BUILD_DIR"
ctest --test-dir "$BUILD_DIR" --output-on-failure
