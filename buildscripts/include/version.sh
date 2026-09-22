#!/bin/bash

# The NDK is provided by the Nix development environment (see ../flake.nix)
# through ANDROID_NDK_ROOT - there is no NDK version pin or download here.

ANDROID_API="21"

# End of configurable options

if [[ $ARCH = "arm" ]]; then
	ABI="armeabi-v7a"
	NDK_TRIPLET="arm-linux-androideabi"
	FFMPEG_CPU="armv7-a"
	BOOST_ARCH="arm"
	BOOST_ADDRESS_MODEL="32"
	LUAJIT_HOST_CC="gcc -m32"
	ASAN_ARCH="arm"
elif [[ $ARCH = "arm64" ]]; then
	ABI="arm64-v8a"
	NDK_TRIPLET="aarch64-linux-android"
	FFMPEG_CPU="armv8-a"
	BOOST_ARCH="arm"
	BOOST_ADDRESS_MODEL="64"
	LUAJIT_HOST_CC="gcc -m64"
	ASAN_ARCH="aarch64"
elif [[ $ARCH = "x86_64" ]]; then
	ABI="x86_64"
	NDK_TRIPLET="x86_64-linux-android"
	FFMPEG_CPU="intel"
	BOOST_ARCH="x86"
	BOOST_ADDRESS_MODEL="64"
	LUAJIT_HOST_CC="gcc -m64"
elif [[ $ARCH = "x86" ]]; then
	ABI="x86"
	NDK_TRIPLET="i686-linux-android"
	FFMPEG_CPU="intel"
	BOOST_ARCH="x86"
	BOOST_ADDRESS_MODEL="32"
	LUAJIT_HOST_CC="gcc -m32"
else
	echo "Unknown architecture: $ARCH"
	exit 1
fi
