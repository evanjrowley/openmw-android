#!/bin/bash

set -e
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $DIR

export ARCH="arm64"
export CCACHE="false"
ASAN="false"
LTO="false"
BUILD_TYPE="release"
CFLAGS="-fPIC"
CXXFLAGS="-fPIC -frtti -fexceptions"
LDFLAGS=""

usage() {
	echo "Usage: ./build.sh [--help] [--asan] [--arch arch] [--debug|--release]"
	echo "	--help: print this message"
	echo "	--arch: build for specified architecture [arm, arm64, x86_64, x86] (default: arm64)"
	echo "	--asan: build with AddressSanitizer enabled"
	echo "	--lto: use LTO for linking"
	echo "	--ccache: use ccache to speed up repeated builds"
	echo "	--debug: produce a debug build without optimizations"
	echo "	--release: produce a release build with optimizations (default)"
	echo ""
	echo "The Android NDK must be provided through ANDROID_NDK_ROOT; the"
	echo "Nix development environment (nix develop, see ../flake.nix) sets it up."
	exit 0
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
	key="$1"

	case $key in
		--help)
			usage
			shift
			;;
		--arch)
			export ARCH="$2"
			shift 2
			;;
		--asan)
			ASAN=true
			shift
			;;
		--lto)
			LTO=true
			shift
			;;
		--ccache)
			export CCACHE="true"
			shift
			;;
		--debug)
			BUILD_TYPE="debug"
			shift
			;;
		--release)
			BUILD_TYPE="release"
			shift
			;;
		*)
			echo "Invalid argument: $key"
			exit 1
			;;
	esac
done

if [[ $ASAN = true && $ARCH != "arm" && $ARCH != "arm64" ]]; then
	echo "AddressSanitizer is only supported on arm and aarch64 architectures"
	exit 1
fi

source ./include/version.sh

if [[ -z $ANDROID_NDK_ROOT || ! -d $ANDROID_NDK_ROOT ]]; then
	echo "ERROR: ANDROID_NDK_ROOT is not set or does not exist."
	echo "Run this build through 'nix develop' (see ../flake.nix)."
	exit 1
fi
NDK_BIN_DIR="$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/bin"

if [ $ASAN = true ]; then
	CFLAGS="$CFLAGS -fsanitize=address -fno-omit-frame-pointer"
	CXXFLAGS="$CXXFLAGS -fsanitize=address -fno-omit-frame-pointer"
	LDFLAGS="$LDFLAGS -fsanitize=address -fno-omit-frame-pointer"
fi

if [ $BUILD_TYPE = "release" ]; then
	CFLAGS="$CFLAGS -O3"
	CXXFLAGS="$CXXFLAGS -O3"
else
	CFLAGS="$CFLAGS -O0 -g"
	CXXFLAGS="$CXXFLAGS -O0 -g"
fi

if [[ $LTO = "true" ]]; then
	CFLAGS="$CFLAGS -flto"
	CXXFLAGS="$CXXFLAGS -flto"
	LDFLAGS="$LDFLAGS -flto"
fi

if [[ $ARCH = "arm" ]]; then
	CFLAGS="$CFLAGS -mthumb"
	CXXFLAGS="$CXXFLAGS -mthumb"
fi

CCACHE_PREFIX=""
if [[ $CCACHE = "true" ]]; then
	CCACHE_PREFIX="ccache "
fi

echo ""
echo "================================================================================"
echo ""
echo "Build configuration:"
echo " - Architecture: $ARCH ($ABI)"
echo " - Build type: $BUILD_TYPE"
echo " - AddressSanitizer: $ASAN"
echo " - ccache: $CCACHE"
echo " - NDK: $ANDROID_NDK_ROOT"
echo ""
echo " ------------------------------------------------------------------------------ "
echo ""
echo "Computed flags:"
echo " - CFLAGS: $CFLAGS"
echo " - CXXFLAGS: $CXXFLAGS"
echo " - LDFLAGS: $LDFLAGS"
echo ""
echo "================================================================================"
echo "(Please run ./clean.sh manually if you modify any of the options)"
echo ""

NCPU=$(grep -c ^processor /proc/cpuinfo)
echo "==> Build using $NCPU CPUs"
mkdir -p build/$ARCH/
mkdir -p prefix/$ARCH/

# symlink lib64 -> lib so we don't get half the libs in one directory half in another
mkdir -p prefix/$ARCH/lib
ln -sf lib prefix/$ARCH/lib64

# generate command_wrapper.sh
cat include/command_wrapper_head.sh.in | \
	DIR=$DIR \
	ARCH=$ARCH \
	ENV_CFLAGS=$CFLAGS \
	ENV_CXXFLAGS=$CXXFLAGS \
	NDK_TRIPLET=$NDK_TRIPLET \
	ANDROID_API=$ANDROID_API \
	NDK_BIN_DIR=$NDK_BIN_DIR \
	CCACHE_PREFIX="$CCACHE_PREFIX" \
	ENV_LDFLAGS=$LDFLAGS \
		envsubst > build/$ARCH/command_wrapper.sh
cat include/command_wrapper_tail.sh.in >> build/$ARCH/command_wrapper.sh
chmod +x build/$ARCH/command_wrapper.sh

# generate boost user-config.jam (b2 toolset config)
cat include/boost-user-config.jam.in | \
	DIR=$DIR \
	NDK_TRIPLET=$NDK_TRIPLET \
	ANDROID_API=$ANDROID_API \
	NDK_BIN_DIR=$NDK_BIN_DIR \
	CCACHE_PREFIX="$CCACHE_PREFIX" \
		envsubst > build/$ARCH/boost-user-config.jam
cat build/$ARCH/boost-user-config.jam

pushd build/$ARCH/

# Get CC/CXX/etc vars
source ./command_wrapper.sh true

# Build!
cmake ../.. \
	-DCMAKE_INSTALL_PREFIX=$DIR/prefix/$ARCH/ \
	-DARCH=$ARCH \
	-DBUILD_TYPE=$BUILD_TYPE \
	-DANDROID_NDK_ROOT=$ANDROID_NDK_ROOT \
	-DANDROID_API=$ANDROID_API \
	-DNDK_TRIPLET=$NDK_TRIPLET \
	-DABI=$ABI \
	-DUSE_CCACHE=$CCACHE \
	-DBOOST_USER_CONFIG=$DIR/build/$ARCH/boost-user-config.jam \
	-DBOOST_ARCH=$BOOST_ARCH \
	-DBOOST_ADDRESS_MODEL=$BOOST_ADDRESS_MODEL \
	-DLUAJIT_HOST_CC="$LUAJIT_HOST_CC" \
	-DFFMPEG_CPU=$FFMPEG_CPU
make -j$NCPU

popd

# gl4es hardcodes soname "libGL.so.1"; Android's linker must find "libGL.so"
patchelf --set-soname libGL.so prefix/$ARCH/lib/libGL.so

echo "==> Installing shared libraries"

# Refresh only the dependency libs this script owns. libopenmw.so is the
# Phase 2 (build-openmw.sh) product and must survive a deps-only rebuild.
mkdir -p ../app/src/main/jniLibs/$ABI/
rm -f ../app/src/main/jniLibs/$ABI/libopenal.so \
	../app/src/main/jniLibs/$ABI/libSDL2.so \
	../app/src/main/jniLibs/$ABI/libGL.so \
	../app/src/main/jniLibs/$ABI/libc++_shared.so

# copy over libs we compiled (hidapi is built into libSDL2.so since 2.30)
cp prefix/$ARCH/lib/{libopenal,libSDL2,libGL}.so ../app/src/main/jniLibs/$ABI/

# copy over libc++_shared
find "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/$NDK_TRIPLET" \
	-iname "libc++_shared.so" -exec cp "{}" ../app/src/main/jniLibs/$ABI/ \;

# NOTE: libopenmw.so and the OpenMW resources (resources/, defaults.bin,
# openmw.cfg, gamecontrollerdb.txt) are produced by the Phase 2 build of
# OpenMW 0.51 itself, not here.

echo "==> Making your debugging life easier"

# copy unstripped libs to aid debugging
rm -rf "./symbols/$ABI/" && mkdir -p "./symbols/$ABI/"
cp prefix/$ARCH/lib/libopenal.so "./symbols/$ABI/" || true
find build/$ARCH/sdl2-prefix/src/sdl2-build/ -name "libSDL2.so" -exec cp "{}" "./symbols/$ABI/" \; || true
find build/$ARCH/gl4es-prefix/src/gl4es/lib/ -name "libGL.so*" -exec cp "{}" "./symbols/$ABI/" \; || true
cp "../app/src/main/jniLibs/$ABI/libc++_shared.so" "./symbols/$ABI/"

if [ $ASAN = true ]; then
	find "$ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/lib" \
		-iname "libclang_rt.asan-$ASAN_ARCH-android.so" -exec cp "{}" "./symbols/$ABI/" \; \
		-exec cp "{}" "../app/src/main/jniLibs/$ABI/" \;
	mkdir -p ../app/wrap/res/lib/$ABI/
	sed "s/@ASAN_ARCH@/$ASAN_ARCH/g" < include/asan-wrapper.sh > "../app/wrap/res/lib/$ABI/wrap.sh"
	chmod +x "../app/wrap/res/lib/$ABI/wrap.sh"
fi

# gradle should do it, but just in case...
$NDK_BIN_DIR/llvm-strip ../app/src/main/jniLibs/$ABI/*.so

echo "==> Success"
