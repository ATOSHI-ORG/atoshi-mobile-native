#!/usr/bin/env bash
#
# Build rapidsnark for iOS device + simulator as XCFramework.
#
# Prerequisites:
#   - Xcode 14+ with command-line tools
#   - cmake >= 3.20  (brew install cmake)
#   - nasm           (brew install nasm)
#   - git
#
# Output:
#   ./Rapidsnark.xcframework/

set -euo pipefail
cd "$(dirname "$0")"

RAPIDSNARK_DIR="${RAPIDSNARK_DIR:-$(pwd)/rapidsnark-src}"

if [[ ! -d "$RAPIDSNARK_DIR" ]]; then
  git clone https://github.com/iden3/rapidsnark.git "$RAPIDSNARK_DIR"
  pushd "$RAPIDSNARK_DIR" >/dev/null
  git submodule init && git submodule update
  popd >/dev/null
fi

pushd "$RAPIDSNARK_DIR" >/dev/null

# rapidsnark provides build_gmp.sh ios target
./build_gmp.sh ios || true
./build_gmp.sh ios_simulator || true

build_one() {
  local sysroot="$1" arch="$2" out_subdir="$3"
  local build_dir="build_ios_${out_subdir}"
  rm -rf "$build_dir"
  mkdir "$build_dir"
  pushd "$build_dir" >/dev/null
  cmake .. \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$sysroot" \
    -DCMAKE_OSX_ARCHITECTURES="$arch" \
    -DTARGET_PLATFORM=IOS \
    -DCMAKE_BUILD_TYPE=Release
  cmake --build . --target rapidsnarkStatic -j 4
  popd >/dev/null
}

build_one iphoneos arm64 device
build_one iphonesimulator "arm64;x86_64" simulator

popd >/dev/null

rm -rf Rapidsnark.xcframework
xcodebuild -create-xcframework \
  -library "$RAPIDSNARK_DIR/build_ios_device/librapidsnarkStatic.a" \
  -library "$RAPIDSNARK_DIR/build_ios_simulator/librapidsnarkStatic.a" \
  -output Rapidsnark.xcframework

echo
echo "✓ Rapidsnark.xcframework built."
echo "  Drag into Xcode, Embed & Sign."
