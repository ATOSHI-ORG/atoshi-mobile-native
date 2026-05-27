#!/usr/bin/env bash
#
# Build atoshi-poseidon Rust crate as iOS static library + XCFramework.
#
# Prerequisites:
#   1. Install Rust:               curl https://sh.rustup.rs -sSf | sh
#   2. Add iOS targets:
#        rustup target add aarch64-apple-ios          # iPhone/iPad
#        rustup target add aarch64-apple-ios-sim      # Apple Silicon simulator
#        rustup target add x86_64-apple-ios           # Intel simulator
#   3. Have Xcode installed (xcrun must be on PATH)
#
# Output:
#   ./AtoshiPoseidon.xcframework/
#       ios-arm64/libatoshi_poseidon.a
#       ios-arm64_x86_64-simulator/libatoshi_poseidon.a
#       Info.plist
#   ./include/atoshi_poseidon.h     (C header for Swift bridging)
#
# Drag AtoshiPoseidon.xcframework into your Xcode project.
# Add ./include/atoshi_poseidon.h to a bridging header for Swift.

set -euo pipefail
cd "$(dirname "$0")"

echo "→ Building for iOS device + simulator..."
cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

mkdir -p out_sim
# Combine arm64-sim + x86_64-sim into one fat sim library
lipo -create \
  target/aarch64-apple-ios-sim/release/libatoshi_poseidon.a \
  target/x86_64-apple-ios/release/libatoshi_poseidon.a \
  -output out_sim/libatoshi_poseidon.a

echo "→ Building XCFramework..."
rm -rf AtoshiPoseidon.xcframework
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libatoshi_poseidon.a \
  -library out_sim/libatoshi_poseidon.a \
  -output AtoshiPoseidon.xcframework

# Generate C header
mkdir -p include
cat > include/atoshi_poseidon.h <<'HEADER'
#ifndef ATOSHI_POSEIDON_H
#define ATOSHI_POSEIDON_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Compute Poseidon hash.
///
/// @param inputs_ptr  Pointer to N concatenated 32-byte big-endian field elements.
/// @param arity       Number of inputs; must be 1..=16.
/// @param out_ptr     32-byte buffer to receive the hash output (big-endian).
/// @return            0 on success, negative on error.
int32_t atoshi_poseidon_hash(const uint8_t *inputs_ptr,
                             size_t arity,
                             uint8_t *out_ptr);

#ifdef __cplusplus
}
#endif

#endif
HEADER

echo
echo "✓ Build succeeded."
echo "  XCFramework: $(pwd)/AtoshiPoseidon.xcframework"
echo "  Header:      $(pwd)/include/atoshi_poseidon.h"
echo
echo "Next steps:"
echo "  1. Drag AtoshiPoseidon.xcframework into your Xcode project (Embed & Sign)."
echo "  2. Add include/atoshi_poseidon.h to a Swift bridging header."
echo "  3. See examples/PoseidonNative.swift for usage."
