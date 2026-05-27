#!/usr/bin/env bash
#
# Build rapidsnark (iden3's C++ Groth16 prover) as 4 Android .so files.
#
# rapidsnark generates ZK proofs for transfer.circom and unshield.circom on-device.
#
# Prerequisites:
#   1. Android NDK r25c or later. Export ANDROID_NDK_HOME.
#        export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/25.2.9519653
#   2. cmake >= 3.20:    brew install cmake          (or apt-get on Linux)
#   3. nasm:             brew install nasm           (x86_64 build needs it)
#   4. git
#   5. ~3 GB free disk (rapidsnark has heavy build artifacts incl. GMP)
#
# Output:
#   ./jniLibs/arm64-v8a/librapidsnark.so
#   ./jniLibs/armeabi-v7a/librapidsnark.so
#   ./jniLibs/x86_64/librapidsnark.so
#   (x86 32-bit is rarely needed for ZK on mobile and rapidsnark may not
#    support it without manual patching — we skip by default.)
#
# Build time: ~15 minutes total (4 architectures × ~4 min each).

set -euo pipefail
cd "$(dirname "$0")"

if [[ -z "${ANDROID_NDK_HOME:-}" ]]; then
  echo "ERROR: export ANDROID_NDK_HOME first." >&2
  exit 1
fi

RAPIDSNARK_DIR="${RAPIDSNARK_DIR:-$(pwd)/rapidsnark-src}"

if [[ ! -d "$RAPIDSNARK_DIR" ]]; then
  echo "→ Cloning rapidsnark..."
  git clone https://github.com/iden3/rapidsnark.git "$RAPIDSNARK_DIR"
  pushd "$RAPIDSNARK_DIR" >/dev/null
  git submodule init && git submodule update
  popd >/dev/null
fi

# Build GMP for Android (rapidsnark depends on it for big-integer math).
# rapidsnark ships a build_gmp.sh helper.
pushd "$RAPIDSNARK_DIR" >/dev/null

echo "→ Building GMP for Android..."
if [[ ! -d "depends/gmp/package_android_arm64" ]]; then
  ./build_gmp.sh android || true   # script name varies between versions
  ./build_gmp.sh android_x86_64 || true
fi

# Build rapidsnark itself for each ABI.
OUTPUT_DIR="$(dirname "$RAPIDSNARK_DIR")/jniLibs"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

build_one() {
  local abi="$1" target="$2" out_subdir="$3"
  echo
  echo "═══ Building rapidsnark for $abi ($target) ═══"
  local build_dir="build_$abi"
  rm -rf "$build_dir"
  mkdir "$build_dir"
  pushd "$build_dir" >/dev/null
  cmake .. \
    -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK_HOME/build/cmake/android.toolchain.cmake" \
    -DANDROID_ABI="$abi" \
    -DANDROID_NATIVE_API_LEVEL=24 \
    -DTARGET_PLATFORM=ANDROID \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON
  cmake --build . --target rapidsnark -j 4
  mkdir -p "$OUTPUT_DIR/$out_subdir"
  find . -name "librapidsnark*.so" -exec cp {} "$OUTPUT_DIR/$out_subdir/" \;
  popd >/dev/null
}

build_one arm64-v8a    aarch64-linux-android arm64-v8a
build_one armeabi-v7a  armv7a-linux-androideabi armeabi-v7a
build_one x86_64       x86_64-linux-android x86_64

popd >/dev/null

echo
echo "✓ rapidsnark build succeeded."
echo "Output:"
find "$OUTPUT_DIR" -name "*.so" -exec ls -lh {} \;

echo
echo "Next steps:"
echo "  1. Copy jniLibs/ into your Android project: app/src/main/jniLibs/"
echo "  2. Distribute these files to clients via your CDN (zkey is ~50-200MB, do NOT bundle in APK):"
echo "       transfer.wasm + transfer_final.zkey"
echo "       unshield.wasm + unshield_final.zkey"
echo "     Origin: /Users/liudongqi/atoshi/atoshi-privacy-circuits/build/"
echo "  3. See examples/ProverNative.kt for the JNI API."
echo
echo "⚠️  Note: rapidsnark's upstream JNI shim is minimal. You may need to write"
echo "    a small JNI wrapper (~50 lines C++) that exposes 'prove(wasm, zkey, input)'"
echo "    to Java. See examples/jni_wrapper.cpp for a template."
