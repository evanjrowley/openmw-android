# No longer under development

You can download one of the old builds from the Releases tab.

# OpenMW for Android

[Google Play](https://play.google.com/store/apps/details?id=is.xyz.omw) | [Google Play (Nightly)](https://play.google.com/store/apps/details?id=is.xyz.omw_nightly)

[F-Droid](https://f-droid.org/packages/is.xyz.omw/) | [F-Droid (Nightly)](https://f-droid.org/packages/is.xyz.omw_nightly/)

[FAQ & Info](https://omw.xyz.is/)

## Building

There are two steps for building OpenMW for Android. The first step is building C/C++ libraries. The second step is building the Java launcher.

### Prerequisites

The build environment is managed declaratively with [Nix](https://nixos.org/) (see `flake.nix`): it provides CMake, ninja, ccache, autotools, a host toolchain, OpenJDK and the Android SDK/NDK (r26d). The only host requirement is Nix itself with flakes enabled.

### Step 1: Build the libraries

Go into the `buildscripts` directory and run:

```
nix develop -c bash -c './build.sh --arch arm64 --ccache'
```

The script will automatically download the dependencies, cross-compile them for Android and install them into `buildscripts/prefix/<arch>`, copying the shared libraries into `app/src/main/jniLibs/`.

Note: this step no longer builds OpenMW itself. For OpenMW 0.51 the engine is cross-built directly from the OpenMW source tree (its own CMake fetches Bullet, MyGUI, OSG, RecastNavigation, yaml-cpp, sqlite and ICU); see the Phase 2 section of the porting plan.

### Step 2: Build the Java launcher

To get an APK file you can install, open the `openmw-android` directory in Android Studio and run the project.

Alternatively, if you do not have Android Studio installed or would rather not use it, run `./gradlew assembleDebug` from the root directory of this repository (also inside `nix develop`). The resulting APK, located at `./app/build/outputs/apk/debug/app-debug.apk`, can be transferred to the device and installed.

## Notes for developers

### Debugging native code

You can debug native code with `ndk-gdb`. To use it, once you've built both libraries and the apk and installed the apk, run the application and let it stay on the main menu. Then `cd` to `app/src/main` and run `./gdb.sh [arch]`. The `arch` variable has to match the library your device will be using (one of `arm`, `arm64`, `x86_64`, `x86`; `arm` is the default).

This also automatically enables gdb to use unstripped libraries, so you get proper symbols, source code references, etc.

### Running Address Sanitizer

To compile everything with ASAN:

```
# Clean previous build
./clean.sh
# Build with ASAN enabled & debug symbols
./build.sh --ccache --asan --debug
# Or: ./build.sh --ccache --asan --debug --arch arm64
```

Then open Android Studio and compile and install the project.

To get symbolized output:

```
adb logcat | ./tool/asan_symbolize.py --demangle -s ./symbols/armeabi-v7a/
# Or: adb logcat | ./tool/asan_symbolize.py --demangle -s ./symbols/arm64-v8a/
```

## Credits

### Source code

Original Java code written by sandstranger. Build scripts originally written by sandstranger and bwhaines.
