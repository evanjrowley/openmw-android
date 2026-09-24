#!/bin/bash

# Build host ICU 70.1, required once before build-openmw.sh.
#
# OpenMW 0.51 cross-builds ICU 70.1 via FetchContent (extern/icu, see the
# OPENMW_USE_SYSTEM_ICU=OFF path). An ICU cross build needs native tools of
# the exact same version, so the host build tree is kept in icu-host/ and
# passed as OPENMW_ICU_HOST_BUILD_DIR. Gitignored; rebuild freely.

set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

ICU_TAG=release-70-1
ICU_URL=https://github.com/unicode-org/icu/archive/refs/tags/${ICU_TAG}.zip
OUT=$DIR/icu-host
SRC=$OUT/icu4c/source

if [[ -e $SRC/lib/libicuuc.so.70 || -e $SRC/lib/libicuuc.a ]]; then
	echo "==> Host ICU 70.1 already built at $SRC"
	exit 0
fi

mkdir -p $DIR/downloads
ZIP=$DIR/downloads/icu-${ICU_TAG}.zip
if [[ ! -e $ZIP ]]; then
	echo "==> Downloading ICU $ICU_TAG"
	curl -fL --retry 3 -o "$ZIP" "$ICU_URL"
fi

echo "==> Extracting"
rm -rf "$OUT"
mkdir -p "$OUT"
TMP=$(mktemp -d)
unzip -oq "$ZIP" -d "$TMP"
mv "$TMP"/icu-${ICU_TAG}/icu4c "$OUT/icu4c"
rm -rf "$TMP"

echo "==> Configuring"
cd $SRC
./configure --disable-tests --disable-samples --disable-icuio --disable-extras \
	--prefix=$OUT/prefix CC=gcc CXX=g++

echo "==> Building"
make -j$(grep -c ^processor /proc/cpuinfo)

echo "==> Success: $SRC"
