#!/usr/bin/env bash
#
# Cross-compile atoshi-arkworks-prover (license-friendly Groth16 prover)
# to 4 Android .so files.
#
# This is the LICENSE-FRIENDLY alternative to rapidsnark/build-android.sh.
# Use this for closed-source / commercial wallet apps.
#
# Prerequisites: same as ../poseidon/build-android.sh (Rust + Android NDK + cargo-ndk).
#
# Output:
#   ./jniLibs/arm64-v8a/libatoshi_arkworks_prover.so
#   ./jniLibs/armeabi-v7a/libatoshi_arkworks_prover.so
#   ./jniLibs/x86/libatoshi_arkworks_prover.so
#   ./jniLibs/x86_64/libatoshi_arkworks_prover.so
#
# Build time: ~10 minutes (arkworks is a big crate tree).

set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ERROR: export ANDROID_NDK_HOME first." >&2
  exit 1
fi

if ! command -v cargo-ndk >/dev/null 2>&1; then
  echo "Installing cargo-ndk (one-time)..."
  cargo install cargo-ndk
fi

OUTPUT_DIR="$(pwd)/jniLibs"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

echo "→ Building arkworks Groth16 prover for arm64/armv7/x86/x86_64 (release)..."
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
echo "  1. Copy jniLibs/* → app/src/main/jniLibs/ in your Android project"
echo "  2. Use examples/ProverNative.kt"
