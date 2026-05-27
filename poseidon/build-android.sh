#!/usr/bin/env bash
#
# Cross-compile atoshi-poseidon Rust crate to 4 Android .so files
# (one per ABI: arm64-v8a, armeabi-v7a, x86, x86_64).
#
# Prerequisites (one-time setup on the build machine):
#   1. Install Rust:                curl https://sh.rustup.rs -sSf | sh
#   2. Add Android targets:
#        rustup target add aarch64-linux-android
#        rustup target add armv7-linux-androideabi
#        rustup target add i686-linux-android
#        rustup target add x86_64-linux-android
#   3. Install Android NDK (r25c or later):
#        sdkmanager --install "ndk;25.2.9519653"
#      Or download from https://developer.android.com/ndk/downloads
#   4. Export ANDROID_NDK_HOME=/path/to/android-ndk
#   5. Install cargo-ndk for easier cross-compile:
#        cargo install cargo-ndk
#
# Output:
#   ./jniLibs/arm64-v8a/libatoshi_poseidon.so
#   ./jniLibs/armeabi-v7a/libatoshi_poseidon.so
#   ./jniLibs/x86/libatoshi_poseidon.so
#   ./jniLibs/x86_64/libatoshi_poseidon.so
#
# Copy ./jniLibs/* into your Android Studio project:
#   app/src/main/jniLibs/
#
set -euo pipefail

cd "$(dirname "$0")"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ERROR: export ANDROID_NDK_HOME=/path/to/android-ndk first" >&2
  echo "Example: export ANDROID_NDK_HOME=\$HOME/Library/Android/sdk/ndk/25.2.9519653" >&2
  exit 1
fi

if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "Installing cargo-ndk (one-time)..."
  cargo install cargo-ndk
fi

OUTPUT_DIR="$(pwd)/jniLibs"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "→ Building for arm64-v8a, armeabi-v7a, x86, x86_64 (release)"
cargo ndk \
  -t arm64-v8a \
  -t armeabi-v7a \
  -t x86 \
  -t x86_64 \
  -o "$OUTPUT_DIR" \
  build --release

echo
echo "✓ Build succeeded. Output:"
find "$OUTPUT_DIR" -name "*.so" -exec ls -lh {} \;

echo
echo "Next steps:"
echo "  1. Copy jniLibs/ into your Android project: app/src/main/jniLibs/"
echo "  2. In your Kotlin code, see examples/PoseidonNative.kt for usage."
