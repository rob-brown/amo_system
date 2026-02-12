#!/bin/sh

export PICO_SDK_PATH=~/code/pico-sdk
export PATH="/opt/arm-gnu-toolchain/bin:$PATH"

mkdir build
cd build
cmake ..
make -j4
