#!/bin/bash

# Phase 2: cross-build libopenmw.so from OpenMW 0.51 for Android.
#
# Usage (from the Nix environment, see ../flake.nix):
#   ./build-openmw.sh [--arch arm64] [--debug]
#
# Expects the OpenMW source in a git checkout/worktree at the pinned tag
# (default ../openmw-0.51 relative to this repository; override with
# OPENMW_SRC). Android port patches from patches/openmw-0.51/ are applied
# to it with `git apply` (idempotent).

set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

ARCH="arm64"
BUILD_TYPE="Release"
OPENMW_REF="openmw-0.51.0"

while [[ $# -gt 0 ]]; do
	case $1 in
		--arch)
			ARCH="$2"
			shift 2
			;;
		--debug)
			BUILD_TYPE="Debug"
			shift
			;;
		*)
			echo "Unknown argument: $1"
			exit 1
			;;
	esac
done

source ./include/version.sh

if [[ -z $ANDROID_NDK_ROOT || ! -d $ANDROID_NDK_ROOT ]]; then
	echo "ERROR: ANDROID_NDK_ROOT is not set. Run through 'nix develop' (see ../flake.nix)."
	exit 1
fi

REPO_ROOT=$(cd $DIR/.. && pwd)
OPENMW_SRC=${OPENMW_SRC:-$REPO_ROOT/../openmw-0.51}
PREFIX=$DIR/prefix/$ARCH
BUILD_DIR=$DIR/build/openmw-$ARCH
ICU_HOST=$DIR/icu-host/icu4c/source

if [[ ! -e $OPENMW_SRC/.git ]]; then
	echo "ERROR: OpenMW source not found at $OPENMW_SRC"
	echo "Create it from the openmw clone:"
	echo "  git -C <openmw clone> worktree add $OPENMW_SRC $OPENMW_REF"
	exit 1
fi

echo "==> Applying Android patches to $OPENMW_SRC"
for p in $DIR/patches/openmw-0.51/*.patch; do
	if git -C $OPENMW_SRC apply --check "$p" 2>/dev/null; then
		git -C $OPENMW_SRC apply "$p"
		echo "    applied $(basename $p)"
	elif git -C $OPENMW_SRC apply -R --check "$p" 2>/dev/null; then
		echo "    already applied: $(basename $p)"
	else
		echo "ERROR: patch does not apply: $p"
		exit 1
	fi
done

if [[ ! -d $ICU_HOST/lib ]]; then
	echo "ERROR: host ICU build not found at $ICU_HOST"
	echo "Build it first (required for OPENMW_USE_SYSTEM_ICU=OFF):"
	echo "  See README: buildscripts/icu-host (host ICU 70.1, needed once)"
	exit 1
fi

CFLAGS="-fPIC -O3"
CXXFLAGS="-fPIC -frtti -fexceptions -O3"

export PKG_CONFIG_LIBDIR=$PREFIX/lib/pkgconfig

NCPU=$(grep -c ^processor /proc/cpuinfo)
echo "==> Building with $NCPU CPUs"
mkdir -p $BUILD_DIR
cd $BUILD_DIR

# gl4es provides desktop GL; satisfy CMake's GLVND-era FindOpenGL checks
GL4ES=$PREFIX/lib/libGL.so

cmake $OPENMW_SRC \
	-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK_ROOT/build/cmake/android.toolchain.cmake \
	-DANDROID_ABI=$ABI \
	-DANDROID_PLATFORM=android-$ANDROID_API \
	-DANDROID_STL=c++_shared \
	-DANDROID_CPP_FEATURES="rtti exceptions" \
	-DCMAKE_BUILD_TYPE=$BUILD_TYPE \
	-DCMAKE_C_COMPILER_LAUNCHER=ccache \
	-DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
	-DCMAKE_INSTALL_PREFIX=$BUILD_DIR/install \
	-DOPENMW_DEPENDENCIES_DIR=$PREFIX \
	-DBUILD_OPENMW=ON \
	-DBUILD_LAUNCHER=OFF \
	-DBUILD_OPENCS=OFF \
	-DBUILD_WIZARD=OFF \
	-DBUILD_BSATOOL=OFF \
	-DBUILD_NIFTEST=OFF \
	-DBUILD_ESMTOOL=OFF \
	-DBUILD_MWINIIMPORTER=OFF \
	-DBUILD_ESSIMPORTER=OFF \
	-DBUILD_NAVMESHTOOL=OFF \
	-DBUILD_BULLETOBJECTTOOL=OFF \
	-DBUILD_DOCS=OFF \
	-DBUILD_COMPONENTS_TESTS=OFF \
	-DBUILD_OPENMW_TESTS=OFF \
	-DBUILD_OPENCS_TESTS=OFF \
	-DBUILD_BENCHMARKS=OFF \
	-DOPENMW_GL4ES_MANUAL_INIT=ON \
	-DOPENMW_USE_SYSTEM_MYGUI=OFF \
	-DOPENMW_USE_SYSTEM_OSG=OFF \
	-DOPENMW_USE_SYSTEM_BULLET=OFF \
	-DOPENMW_USE_SYSTEM_RECASTNAVIGATION=OFF \
	-DOPENMW_USE_SYSTEM_SQLITE3=OFF \
	-DOPENMW_USE_SYSTEM_YAML_CPP=OFF \
	-DOPENMW_USE_SYSTEM_ICU=OFF \
	-DOPENMW_ICU_HOST_BUILD_DIR=$ICU_HOST \
	-DOSG_STATIC=ON \
	-DBoost_USE_STATIC_RUNTIME=ON \
	-DMYGUI_STATIC=ON \
	-DOPENGL_gl_LIBRARY=$GL4ES \
	-DOPENGL_opengl_LIBRARY=$GL4ES \
	-DOPENGL_glx_LIBRARY=$GL4ES \
	-DOPENGL_GLX_INCLUDE_DIR=$PREFIX/include \
	-DJPEG_INCLUDE_DIR=$PREFIX/include \
	-DJPEG_LIBRARY=$PREFIX/lib/libjpeg.a \
	-DPNG_PNG_INCLUDE_DIR=$PREFIX/include \
	-DPNG_LIBRARY=$PREFIX/lib/libpng16.a \
	-DOPENGL_INCLUDE_DIR=$PREFIX/include \
	-DLZ4_LIBRARY=$PREFIX/lib/liblz4.a \
	-DLZ4_INCLUDE_DIR=$PREFIX/include \
	-DZLIB_INCLUDE_DIR=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/include \
	-DZLIB_LIBRARY=$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$NDK_TRIPLET/$ANDROID_API/libz.so \
	-DFREETYPE_LIBRARY=$PREFIX/lib/libfreetype.a \
	-DFREETYPE_INCLUDE_DIR_ft2build=$PREFIX/include/freetype2 \
	-DFREETYPE_INCLUDE_DIR_freetype2=$PREFIX/include/freetype2 \
	-DOPENAL_INCLUDE_DIR=$PREFIX/include/AL \
	-DOPENAL_LIBRARY=$PREFIX/lib/libopenal.so \
	-DCMAKE_C_FLAGS="$CFLAGS" \
	-DCMAKE_CXX_FLAGS="$CXXFLAGS"

cmake --build . --target openmw -j$NCPU

echo "==> Installing libopenmw.so"
mkdir -p $REPO_ROOT/app/src/main/jniLibs/$ABI/
find $BUILD_DIR -name "libopenmw.so" -exec cp "{}" $REPO_ROOT/app/src/main/jniLibs/$ABI/ \;

echo "==> Deploying resources"
DST=$REPO_ROOT/app/src/main/assets/libopenmw/
rm -rf "$DST" && mkdir -p "$DST/openmw/"
cp -r $BUILD_DIR/resources "$DST"
cp $BUILD_DIR/defaults.bin $DST/openmw/
cp $BUILD_DIR/gamecontrollerdb.txt $DST/openmw/
cat $BUILD_DIR/openmw.cfg | grep -v "^data=" | grep -v "^data-local=" > $DST/openmw/openmw.base.cfg
cat $REPO_ROOT/app/openmw.base.cfg >> $DST/openmw/openmw.base.cfg
cp $REPO_ROOT/3rdparty-licenses.txt $DST/

echo "==> Stripping"
$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin/llvm-strip $REPO_ROOT/app/src/main/jniLibs/$ABI/libopenmw.so

echo "==> Success: $REPO_ROOT/app/src/main/jniLibs/$ABI/libopenmw.so"
