# OpenMW for Android — OpenMW 0.51.0

Android port of [OpenMW](https://openmw.org/) **0.51.0**, a modern open-source
reimplementation of The Elder Scrolls III: Morrowind. This fork revives the
archived OpenMW for Android project (the 0.48-era codebase) and updates it to
OpenMW 0.51.0 for modern arm64-v8a devices — developed and tested on a
Retroid Pocket 6.

Actively developed on the `openmw-0.51` branch.

## Status

* The engine is upstream **OpenMW 0.51.0** with an Android runtime patch
  series (rendering, input, lifecycle) carried in this repository.
* CI builds the APK from a clean checkout on every push to `openmw-0.51`
  (see `.github/workflows/ci.yml`); the APK and unstripped `libopenmw.so`
  are published as workflow artifacts. Release builds are tagged
  (e.g. `0.51.0-50`).
* This fork is not distributed through Google Play or F-Droid, and it is
  not affiliated with https://omw.xyz.is/ — build it yourself or grab the
  artifacts from the Actions/Releases tabs.

**You must supply your own game data files** from a legitimately obtained
copy of The Elder Scrolls III: Morrowind (point the launcher at the
Morrowind `Data Files` directory on first launch).

## Building

Everything is managed declaratively with [Nix](https://nixos.org/) (see
`flake.nix`): the Android SDK/NDK (r28.2), OpenJDK 17, cmake, ninja, ccache
and autotools. The only host requirement is Nix with flakes enabled.

The build has three steps: the C/C++ dependency layer, the OpenMW engine
itself, and the Java launcher (APK).

### Prerequisites

A checkout of upstream OpenMW at the `openmw-0.51.0` tag as a git worktree
next to this repository (the engine build expects it at `../openmw-0.51`;
CI performs this step automatically):

```
git clone https://github.com/OpenMW/openmw.git
git -C openmw worktree add ../openmw-0.51 openmw-0.51.0
```

### Step 1: Build the dependency layer

From the `buildscripts` directory:

```
nix develop -c bash -c './build.sh --arch arm64 --ccache'
```

Downloads and cross-compiles the dependencies (Boost, SDL2, OpenAL, FFmpeg,
gl4es, LuaJIT, lz4, …), installing them into `buildscripts/prefix/<arch>`
and copying the shared libraries into `app/src/main/jniLibs/`.

### Step 2: Build the host ICU (once)

```
nix develop -c bash build-icu-host.sh
```

Builds the host-side ICU 70.1 required by OpenMW's ICU cross-build.
Idempotent; only needed the first time (or after `buildscripts/icu-host`
is removed).

### Step 3: Build the OpenMW engine

```
nix develop -c bash -c './build-openmw.sh'
```

Cross-builds `libopenmw.so` from the OpenMW source tree (applying the
Android patch series under `buildscripts/patches/`), copies it into
`app/src/main/jniLibs/` and deploys the engine assets (vfs, shaders,
defaults) into `app/src/main/assets/`.

### Step 4: Build the APK

From the repository root:

```
nix develop -c ./gradlew assembleNightlyDebug
```

The resulting APK lands at
`app/build/outputs/apk/nightly/debug/omw_debug_<version>.apk`; transfer it
to the device and install. `assembleMainlineDebug` builds the non-nightly
variant.

## CI

GitHub Actions (`.github/workflows/ci.yml`) runs the same pipeline from a
clean checkout on every push to `openmw-0.51` and publishes the APK and an
unstripped `libopenmw.so` as workflow artifacts. The dependency-layer
caches (Nix store, ICU, prefix, ccache) make follow-up runs substantially
faster than the first.

## Notes for developers

### Debugging native code

You can debug native code with `ndk-gdb`. To use it, once you've built the
libraries and the APK and installed the APK, run the application and let it
stay on the main menu. Then `cd` to `app/src/main` and run `./gdb.sh [arch]`.
The `arch` variable has to match the library your device will use
(`arm64` is the relevant one for this port).

This also automatically enables gdb to use unstripped libraries, so you get
proper symbols, source code references, etc.

### Engine patches

The Android-specific engine changes live under `buildscripts/patches/`:
`openmw-0.51/` (the OpenMW patch series, applied by `build-openmw.sh` on a
pristine source tree) and `sdl2/` (the SDL Android controller-mapping fix).
`patches/openmw-0.51-android/` contains the vendored reference patch stack
that the engine build applies first.

## Credits

### Source code

Original Java code written by sandstranger. Build scripts originally written
by sandstranger and bwhaines. OpenMW 0.51 Android runtime patches adapted in
part from the Andiweli/OpenMW-Android reference port. Upstream engine:
[OpenMW](https://openmw.org/). This fork builds on the archived
[xyzz/openmw-android](https://github.com/xyzz/openmw-android) codebase.
