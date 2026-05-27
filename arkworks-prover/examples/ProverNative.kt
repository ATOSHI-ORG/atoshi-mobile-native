package xyz.atoshi.prover

/**
 * License-friendly Groth16 prover bridge (arkworks-rs, Apache-2.0/MIT).
 *
 * Drop-in replacement for rapidsnark's ProverNative.kt — same Kotlin API,
 * same proof JSON format. Differences:
 *   - License: permissive (closed-source apps OK)
 *   - Speed: ~2-3x slower than rapidsnark (10-15s on flagship phones)
 *   - Size: ~5-8 MB .so per ABI
 *   - Requires .r1cs file in addition to .wasm + .zkey
 *
 * Setup:
 *   1. ../build-android.sh produces libatoshi_arkworks_prover.so files
 *   2. Place this file at app/src/main/java/xyz/atoshi/prover/ProverNative.kt
 *   3. Distribute .wasm + .r1cs + _final.zkey via CDN
 *
 * Origin of artifacts:
 *   /Users/liudongqi/atoshi/atoshi-privacy-circuits/build/<circuit>/<circuit>_js/<circuit>.wasm
 *   /Users/liudongqi/atoshi/atoshi-privacy-circuits/build/<circuit>/<circuit>.r1cs
 *   /Users/liudongqi/atoshi/atoshi-privacy-circuits/keys/<circuit>_final.zkey
 */
object ProverNative {
    init {
        System.loadLibrary("atoshi_arkworks_prover")
    }

    /**
     * Generate a Groth16 proof.
     *
     * @param wasmPath  Absolute path to circuit witness-generator wasm.
     * @param r1csPath  Absolute path to circuit constraint system (.r1cs).
     * @param zkeyPath  Absolute path to proving key.
     * @param inputJson Witness input JSON (all signal names → field elements).
     * @return Proof JSON string compatible with snarkjs format.
     * @throws RuntimeException on failure.
     */
    @JvmStatic
    external fun prove(
        wasmPath: String,
        r1csPath: String,
        zkeyPath: String,
        inputJson: String
    ): String
}
