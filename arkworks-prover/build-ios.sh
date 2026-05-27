#!/usr/bin/env bash
# License-friendly Groth16 prover, iOS XCFramework build.
# Same approach as ../poseidon/build-ios.sh.

set -euo pipefail
cd "$(dirname "$0")"

cargo build --release --target aarch64-apple-ios
cargo build --release --target aarch64-apple-ios-sim
cargo build --release --target x86_64-apple-ios

mkdir -p out_sim
lipo -create \
  target/aarch64-apple-ios-sim/release/libatoshi_arkworks_prover.a \
  target/x86_64-apple-ios/release/libatoshi_arkworks_prover.a \
  -output out_sim/libatoshi_arkworks_prover.a

rm -rf AtoshiArkworksProver.xcframework
xcodebuild -create-xcframework \
  -library target/aarch64-apple-ios/release/libatoshi_arkworks_prover.a \
  -library out_sim/libatoshi_arkworks_prover.a \
  -output AtoshiArkworksProver.xcframework

mkdir -p include
cat > include/atoshi_arkworks_prover.h <<'HEADER'
#ifndef ATOSHI_ARKWORKS_PROVER_H
#define ATOSHI_ARKWORKS_PROVER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Generate a Groth16 proof. All path/json args are null-terminated UTF-8.
/// out_buf_len is in/out: in = capacity, out = actual length.
/// Returns 0 on success, negative on error.
int32_t atoshi_prove(const char* wasm_path,
                     const char* r1cs_path,
                     const char* zkey_path,
                     const char* input_json,
                     uint8_t* out_buf,
                     size_t* out_buf_len);

#ifdef __cplusplus
}
#endif

#endif
HEADER

echo "✓ AtoshiArkworksProver.xcframework built."
