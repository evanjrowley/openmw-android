#!/bin/bash

set -e

./clean.sh --all

# Must run inside the Nix environment (nix develop, see ../flake.nix).
if [[ -z $ANDROID_NDK_ROOT || ! -d $ANDROID_NDK_ROOT ]]; then
	echo "ERROR: ANDROID_NDK_ROOT is not set. Run: nix develop -c $0"
	exit 1
fi

./build.sh --arch arm64 --lto --ccache
./build.sh --arch arm --lto --ccache &
PID1=$!

./build.sh --arch x86_64 --lto --ccache &
PID2=$!

./build.sh --arch x86 --lto --ccache &
PID3=$!

wait $PID1 $PID2 $PID3
