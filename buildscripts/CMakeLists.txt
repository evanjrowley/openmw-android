cmake_minimum_required(VERSION 3.22)

# Phase 1: native dependency layer for OpenMW 0.51 on Android.
#
# This builds ONLY the libraries OpenMW still expects to find pre-built
# (see openmw's CMakeLists.txt: Boost, SDL2, OpenAL, FFmpeg, LZ4, LuaJIT,
# plus freetype/libpng/libjpeg for OSG's image plugins and gl4es for the
# GL renderer). Bullet, MyGUI, RecastNavigation, yaml-cpp, sqlite, ICU and
# OSG itself are no longer built here - OpenMW 0.51 fetches and cross-builds
# them itself via FetchContent/ExternalProject during its own configure.
#
# The NDK is provided by the Nix development environment (flake.nix) through
# ANDROID_NDK_ROOT. Consumed variables:
#   ANDROID_NDK_ROOT, ABI, ANDROID_API, NDK_TRIPLET, ARCH, BUILD_TYPE,
#   BOOST_ARCH, BOOST_ADDRESS_MODEL, LUAJIT_HOST_CC, FFMPEG_CPU, USE_CCACHE

#  set the timestamps of extracted contents to the time of extraction
# remove if cmake version is >= 3.24
if(POLICY CMP0135)
	cmake_policy(SET CMP0135 NEW)
endif()

project(openmw-android-deps)

include(ExternalProject)

if(NOT ANDROID_NDK_ROOT)
	message(FATAL_ERROR "ANDROID_NDK_ROOT is not set. Run the build through 'nix develop' (see flake.nix).")
endif()
set(NDK_TOOLCHAIN_FILE ${ANDROID_NDK_ROOT}/build/cmake/android.toolchain.cmake)
set(NDK_BIN_DIR ${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/bin)
set(NDK_SYSROOT ${ANDROID_NDK_ROOT}/toolchains/llvm/prebuilt/linux-x86_64/sysroot)

# https://github.com/libjpeg-turbo/libjpeg-turbo/releases
set(LIBJPEG_TURBO_VERSION 3.0.4)
set(LIBJPEG_TURBO_HASH SHA256=99130559e7d62e8d695f2c0eaeef912c5828d5b84a0537dcb24c9678c9d5b76b)

# http://www.libpng.org/pub/png/libpng.html
set(LIBPNG_VERSION 1.6.43)
set(LIBPNG_HASH SHA256=fecc95b46cf05e8e3fc8a414750e0ba5aad00d89e9fdf175e94ff041caf1a03a)

# https://freetype.org/index.html#news
set(FREETYPE2_VERSION 2.13.3)
set(FREETYPE2_HASH SHA256=5c3a8e78f7b24c20b25b54ee575d6daa40007a5f4eea2845861c3409b3021747)

# https://github.com/kcat/openal-soft/releases
set(OPENAL_VERSION 1.23.1)
set(OPENAL_HASH SHA256=dfddf3a1f61059853c625b7bb03de8433b455f2f79f89548cbcbd5edca3d4a4a)

# http://www.boost.org/users/download/
set(BOOST_VERSION 1.83.0)
set(BOOST_HASH SHA256=6478edfe2f3305127cffe8caf73ea0176c53769f4bf1585be237eb30798c3b8e)

# https://www.ffmpeg.org/download.html
set(FFMPEG_VERSION 6.1.2)
set(FFMPEG_HASH SHA256=62fe9fd098cb537d4b61731b11049e1ac179f38c870a41b8e9d556af944edb45)

# https://www.libsdl.org/download-2.0.php
set(SDL2_VERSION 2.30.12)
set(SDL2_HASH SHA256=ac356ea55e8b9dd0b2d1fa27da40ef7e238267ccf9324704850d5d47375b48ea)

# https://github.com/lz4/lz4/releases
set(LZ4_VERSION 1.9.4)
set(LZ4_HASH SHA256=0b0e3aa07c8c063ddf40b082bdf7e37a1562bda40a0ff5272957f3e987e0e54b)

# https://luajit.org/git/luajit.html - v2.1 branch snapshot
set(LUAJIT_VERSION c6ffc141a8762b41703f9287d63d93622a13dd8f)
set(LUAJIT_HASH SHA256=6e5fec07750add912e7c3eae0c194d24cd6d023714e1f04a0298a5b4819e4457)

# https://github.com/sisah2/gl4es - OpenMW-tuned gl4es fork (as used by the
# reference 0.51 Android port): ships highp fog/precision fixes, disabled
# shader hacks, precompiled-shader-archive support and the 0x4242 gamma hook
# natively. Do not bump to ptitSeb master casually.
set(GL4ES_VERSION 5ac069d82ad8ca2cc3c574484e4c5bad880db83e)
set(GL4ES_HASH SHA256=60ee788c2b43a5a25cd1a8a0071a77e957f2d5ff070eda5c39eb120d1ad2c3ea)

# End of configurable options

set(wrapper_command ${CMAKE_BINARY_DIR}/command_wrapper.sh)
set(download_dir ${CMAKE_SOURCE_DIR}/downloads/)
set(prefix ${CMAKE_INSTALL_PREFIX})
set(android_platform android-${ANDROID_API})
set(app_abi ${ABI})

set(CC_LAUNCHER "")
if(USE_CCACHE)
	set(CC_LAUNCHER ccache)
endif()

set(COMMON_CMAKE_ARGS
	-DCMAKE_TOOLCHAIN_FILE=${NDK_TOOLCHAIN_FILE}
	-DANDROID_ABI=${app_abi}
	-DANDROID_PLATFORM=${android_platform}
	-DANDROID_STL=c++_shared
	-DANDROID_CPP_FEATURES=rtti\ exceptions
	-DCMAKE_C_COMPILER_LAUNCHER=${CC_LAUNCHER}
	-DCMAKE_CXX_COMPILER_LAUNCHER=${CC_LAUNCHER}
	-DCMAKE_C_FLAGS=$ENV{CFLAGS}
	-DCMAKE_CXX_FLAGS=$ENV{CXXFLAGS}
	-DCMAKE_SHARED_LINKER_FLAGS=$ENV{LDFLAGS}
	-DCMAKE_BUILD_TYPE=${BUILD_TYPE}
	-DCMAKE_DEBUG_POSTFIX=
	-DCMAKE_INSTALL_PREFIX=${prefix}
	-DCMAKE_FIND_ROOT_PATH=${prefix}
)

set(COMMON_AUTOCONF_FLAGS
	--enable-static
	--disable-shared
	--prefix=${prefix}
)

# ffmpeg doesn't like --host, so sandwich it between adding --host to the flags
set(ffmpeg_configure_flags ${COMMON_AUTOCONF_FLAGS})
if (${BUILD_TYPE} STREQUAL "debug")
	# ffmpeg fails to compile if we have asm enabled and optimizations disabled, so disable both
	set(ffmpeg_configure_flags ${ffmpeg_configure_flags} --disable-asm --disable-optimizations)
endif()

set(COMMON_AUTOCONF_FLAGS
	--host=${NDK_TRIPLET}
	${COMMON_AUTOCONF_FLAGS}
)

if ((${ARCH} STREQUAL "x86_64") OR (${ARCH} STREQUAL "x86"))
	# ffmpeg fails to link with assembly optimizations on x86-64
	set(ffmpeg_configure_flags ${ffmpeg_configure_flags} --disable-asm)
endif()

# on x86 enabling simd results in text relocations, which are banned on Android
set(libjpeg_turbo_flags "")
if (${ARCH} STREQUAL "x86")
	set(libjpeg_turbo_flags ${libjpeg_turbo_flags} -DWITH_SIMD=0)
endif()

ExternalProject_Add(libjpeg-turbo
	URL https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/${LIBJPEG_TURBO_VERSION}/libjpeg-turbo-${LIBJPEG_TURBO_VERSION}.tar.gz
	URL_HASH ${LIBJPEG_TURBO_HASH}
	DOWNLOAD_DIR ${download_dir}

	CONFIGURE_COMMAND ${wrapper_command} cmake <SOURCE_DIR>
	${COMMON_CMAKE_ARGS}
	-DENABLE_SHARED=0
	-DENABLE_STATIC=1
	-DWITH_TURBOJPEG=0
	${libjpeg_turbo_flags}

	BUILD_COMMAND $(MAKE)

	INSTALL_COMMAND $(MAKE) install
)

ExternalProject_Add(libpng
	DEPENDS libjpeg-turbo

	URL https://github.com/pnggroup/libpng/archive/refs/tags/v${LIBPNG_VERSION}.tar.gz
	URL_HASH ${LIBPNG_HASH}
	DOWNLOAD_DIR ${download_dir}

	CONFIGURE_COMMAND ${wrapper_command} cmake <SOURCE_DIR>
	${COMMON_CMAKE_ARGS}
	-DPNG_SHARED=OFF
	-DPNG_STATIC=ON
	-DPNG_TESTS=OFF
	-DSKIP_INSTALL_PROGRAMS=ON
	-DSKIP_INSTALL_EXECUTABLES=ON
	# hint the NDK sysroot zlib (libpng finds it before FIND_ROOT_PATH kicks in)
	-DZLIB_INCLUDE_DIR=${NDK_SYSROOT}/usr/include
	-DZLIB_LIBRARY=${NDK_SYSROOT}/usr/lib/${NDK_TRIPLET}/${ANDROID_API}/libz.so

	BUILD_COMMAND $(MAKE)

	INSTALL_COMMAND $(MAKE) install
)

ExternalProject_Add(freetype2
	URL https://download.savannah.gnu.org/releases/freetype/freetype-${FREETYPE2_VERSION}.tar.gz
	URL_HASH ${FREETYPE2_HASH}
	DOWNLOAD_DIR ${download_dir}

	CONFIGURE_COMMAND ${wrapper_command} <SOURCE_DIR>/configure
	${COMMON_AUTOCONF_FLAGS}
	--with-png=no
	--with-zlib=no
	--with-bzip2=no
	--with-brotli=no
	--with-harfbuzz=no

	BUILD_COMMAND ${wrapper_command} $(MAKE)

	INSTALL_COMMAND ${wrapper_command} $(MAKE) install
)

ExternalProject_Add(openal
	URL https://github.com/kcat/openal-soft/archive/${OPENAL_VERSION}.tar.gz
	URL_HASH ${OPENAL_HASH}
	DOWNLOAD_DIR ${download_dir}

	CONFIGURE_COMMAND ${wrapper_command} cmake <SOURCE_DIR>
	${COMMON_CMAKE_ARGS}
	-DALSOFT_EXAMPLES=OFF
	-DALSOFT_TESTS=OFF
	-DALSOFT_UTILS=OFF
	-DALSOFT_NO_CONFIG_UTIL=ON
	-DALSOFT_BACKEND_OPENSL=ON
	-DALSOFT_BACKEND_WAVE=OFF

	BUILD_COMMAND ${wrapper_command} $(MAKE)

	INSTALL_COMMAND ${wrapper_command} $(MAKE) install
)

string(REPLACE "." "_" BOOST_VERSION_UNDERSCORE ${BOOST_VERSION})
ExternalProject_Add(boost
	URL https://archives.boost.io/release/${BOOST_VERSION}/source/boost_${BOOST_VERSION_UNDERSCORE}.tar.bz2
	URL_HASH ${BOOST_HASH}
	DOWNLOAD_DIR ${download_dir}

	BUILD_IN_SOURCE 1

	CONFIGURE_COMMAND ${wrapper_command} <SOURCE_DIR>/bootstrap.sh
	--prefix=${prefix}

	BUILD_COMMAND ""

	INSTALL_COMMAND ${wrapper_command} ./b2
	-j4
	--with-iostreams
	--with-program_options
	--ignore-site-config
	--user-config=${BOOST_USER_CONFIG}
	toolset=clang-android
	architecture=${BOOST_ARCH}
	address-model=${BOOST_ADDRESS_MODEL}
	cflags=$ENV{CFLAGS}
	cxxflags=$ENV{CXXFLAGS}
	variant=release
	target-os=android
	threading=multi
	threadapi=pthread
	link=static
	runtime-link=static
	install
	COMMAND ${NDK_BIN_DIR}/llvm-ranlib ${prefix}/lib/libboost_iostreams.a
	COMMAND ${NDK_BIN_DIR}/llvm-ranlib ${prefix}/lib/libboost_program_options.a
)

ExternalProject_Add(ffmpeg
	URL https://ffmpeg.org/releases/ffmpeg-${FFMPEG_VERSION}.tar.bz2
	URL_HASH ${FFMPEG_HASH}
	DOWNLOAD_DIR ${download_dir}

	CONFIGURE_COMMAND ${wrapper_command} <SOURCE_DIR>/configure
	${ffmpeg_configure_flags}
	--target-os=android
	--enable-cross-compile
	--cross-prefix=${NDK_BIN_DIR}/${NDK_TRIPLET}-
	--cc=${CC_LAUNCHER}\ ${NDK_TRIPLET}${ANDROID_API}-clang
	# hide symbols: static libs get linked into libopenmw.so; also avoids
	# ld.lld rejecting adrp+add against preemptible asm-referenced tables
	--extra-cflags=-fvisibility=hidden
	--ar=${NDK_BIN_DIR}/llvm-ar
	--nm=${NDK_BIN_DIR}/llvm-nm
	--ranlib=${NDK_BIN_DIR}/llvm-ranlib
	--strip=${NDK_BIN_DIR}/llvm-strip
	--arch=${ARCH}
	--cpu=${FFMPEG_CPU}
	--enable-version3
	--enable-pic
	--disable-everything
	--disable-doc
	--disable-programs
	--disable-autodetect
	--disable-iconv
	--enable-decoder=mp3
	--enable-demuxer=mp3
	--enable-decoder=bink
	--enable-decoder=binkaudio_rdft
	--enable-decoder=binkaudio_dct
	--enable-demuxer=bink
	--enable-demuxer=wav
	--enable-decoder=pcm_*
	--enable-decoder=vp8
	--enable-decoder=vp9
	--enable-decoder=opus
	--enable-decoder=vorbis
	--enable-demuxer=matroska
	--enable-demuxer=ogg

	BUILD_COMMAND $(MAKE)

	INSTALL_COMMAND $(MAKE) install
)

ExternalProject_Add(sdl2
	URL https://github.com/libsdl-org/SDL/releases/download/release-${SDL2_VERSION}/SDL2-${SDL2_VERSION}.tar.gz
	URL_HASH ${SDL2_HASH}
	DOWNLOAD_DIR ${download_dir}

	CONFIGURE_COMMAND ${wrapper_command} cmake <SOURCE_DIR>
	${COMMON_CMAKE_ARGS}
	-DSDL_SHARED=ON
	-DSDL_STATIC=OFF
	-DSDL_TEST_LIBRARY=OFF
	-DSDL_TESTS=OFF

	BUILD_COMMAND ${wrapper_command} $(MAKE)

	INSTALL_COMMAND ${wrapper_command} $(MAKE) install
	# NOTE: since SDL 2.30's CMake build, hidapi is compiled into libSDL2.so;
	# there is no separate libhidapi.so to install.
)

ExternalProject_Add(lz4
	URL https://github.com/lz4/lz4/archive/v${LZ4_VERSION}.tar.gz
	URL_HASH ${LZ4_HASH}
	DOWNLOAD_DIR ${download_dir}

	CONFIGURE_COMMAND ${wrapper_command} cmake <SOURCE_DIR>/build/cmake/
	${COMMON_CMAKE_ARGS}
	-DBUILD_STATIC_LIBS=ON
	-DBUILD_SHARED_LIBS=OFF
	-DLZ4_BUILD_CLI=OFF
	-DLZ4_BUILD_LEGACY_LZ4C=OFF

	BUILD_COMMAND ${wrapper_command} $(MAKE)

	INSTALL_COMMAND ${wrapper_command} $(MAKE) install
)

set(LUAJIT_MAKE_FLAGS
	HOST_CC=${LUAJIT_HOST_CC}
	CFLAGS=
	TARGET_CFLAGS=$ENV{CFLAGS}
	CROSS=${NDK_BIN_DIR}/${NDK_TRIPLET}-
	# NDK r26 has no <triple>-ar binutils; point make at the llvm tools
	TARGET_AR=${NDK_BIN_DIR}/llvm-ar\ rcus
	TARGET_STRIP=${NDK_BIN_DIR}/llvm-strip
	STATIC_CC=${CC_LAUNCHER}\ ${NDK_BIN_DIR}/${NDK_TRIPLET}${ANDROID_API}-clang
	DYNAMIC_CC=${CC_LAUNCHER}\ ${NDK_BIN_DIR}/${NDK_TRIPLET}${ANDROID_API}-clang\ -fPIC
	TARGET_LD=${NDK_BIN_DIR}/${NDK_TRIPLET}${ANDROID_API}-clang
	PREFIX=${prefix}
)

ExternalProject_Add(luajit
	URL https://github.com/LuaJIT/LuaJIT/archive/${LUAJIT_VERSION}.tar.gz
	URL_HASH ${LUAJIT_HASH}
	DOWNLOAD_DIR ${download_dir}

	BUILD_IN_SOURCE 1

	CONFIGURE_COMMAND ""

	BUILD_COMMAND ${wrapper_command} $(MAKE) amalg
	${LUAJIT_MAKE_FLAGS}

	INSTALL_COMMAND ${wrapper_command} $(MAKE) install
	${LUAJIT_MAKE_FLAGS}
	COMMAND bash -c "rm -f ${prefix}/lib/libluajit*.so*"
)

ExternalProject_Add(gl4es
	URL https://github.com/ptitSeb/gl4es/archive/${GL4ES_VERSION}.tar.gz
	URL_HASH ${GL4ES_HASH}
	DOWNLOAD_DIR ${download_dir}

	# (openmw) GLES2: shaders without main() crash the converter's
	# clip-vertex injection (OpenMW 0.51 lib shaders hit this)
	PATCH_COMMAND patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/gl4es/no-main-null-guard.patch
	COMMAND patch -d <SOURCE_DIR> -p1 -t -N < ${CMAKE_SOURCE_DIR}/patches/gl4es/converted-source-dump.patch

	CONFIGURE_COMMAND ${wrapper_command} cmake <SOURCE_DIR>
	${COMMON_CMAKE_ARGS}
	-DANDROID=ON
	-DNOEGL=ON
	-DNO_LOADER=ON
	-DNO_INIT_CONSTRUCTOR=ON
	-DUSE_ANDROID_LOG=ON

	BUILD_COMMAND ${wrapper_command} $(MAKE)

	# gl4es names its shared library libGL.so.1 (hardcoded SUFFIX); install
	# it under the plain libGL.so name Android's linker expects.
	INSTALL_COMMAND cp -f <SOURCE_DIR>/lib/libGL.so.1 ${prefix}/lib/libGL.so
	COMMAND cp -r <SOURCE_DIR>/include ${prefix}/
	COMMAND mkdir -p ${prefix}/include/gl4es
	COMMAND cp <SOURCE_DIR>/include/gl4esinit.h <SOURCE_DIR>/include/gl4eshint.h ${prefix}/include/gl4es/
)
