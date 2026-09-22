# Declarative development environment for the OpenMW Android port.
#
# Provides every host tool needed to cross-build the native dependency layer
# (buildscripts/), the OpenMW engine itself, and later the Gradle/Java
# launcher — including the Android SDK/NDK via nixpkgs' androidenv.
#
# Usage:
#   nix develop            # drop into the build shell
#   nix develop -c bash -c 'cd buildscripts && ./build.sh --arch arm64'
#
# The Android NDK is fetched from Google by androidenv and exposed through
# ANDROID_NDK_ROOT; buildscripts/build.sh consumes it directly instead of
# downloading its own toolchain copy.

{
  description = "OpenMW for Android build environment";

  inputs = {
    # Pinned release branch; bump deliberately, not incidentally.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
  };

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      devShells = forAllSystems (system:
        let
          # Android SDK/NDK components are unfree and require explicit license
          # acceptance; doing it here keeps the environment self-contained
          # (no global config.nix or NIXPKGS_ACCEPT_ANDROID_SDK_LICENSE needed).
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              android_sdk.accept_license = true;
            };
          };

          androidSdk = (pkgs.androidenv.composeAndroidPackages {
            includeNDK = true;
            # NDK r28.2 (LLVM 19) — full C++20 including std::format;
            ndkVersions = [ "28.2.13676358" ];
            buildToolsVersions = [ "34.0.0" ];
            platformVersions = [ "34" ];
            # Host cmake comes from nixpkgs (newer than the SDK copy).
            includeCmake = false;
          }).androidsdk;

          ndkVersion = "28.2.13676358";
        in
        {
          default = pkgs.mkShell {
            name = "openmw-android-env";

            packages = with pkgs; [
              # Build drivers
              cmake
              ninja
              gnumake
              ccache
              pkg-config
              patchelf # normalize gl4es' libGL.so.1 soname to libGL.so

              # autotools builds (freetype, ffmpeg, ...) and misc
              autoconf
              automake
              libtool
              perl
              python3
              gettext # envsubst, used by buildscripts/build.sh
              unzip
              p7zip
              zip
              which
              file

              # VCS / network diagnostics
              git
              curl

              # Java launcher (Phase 4)
              openjdk17
            ];

            shellHook = ''
              export ANDROID_SDK_ROOT="${androidSdk}/libexec/android-sdk"
              export ANDROID_NDK_ROOT="$ANDROID_SDK_ROOT/ndk/${ndkVersion}"
              export ANDROID_NDK_HOME="$ANDROID_NDK_ROOT"

              echo "[openmw-android-env] NDK: $ANDROID_NDK_ROOT"
              test -d "$ANDROID_NDK_ROOT" || echo "WARNING: NDK missing at $ANDROID_NDK_ROOT"
            '';
          };
        });
    };
}
