package xyz.atoshi.prover

/**
 * JNI bridge to librapidsnark.so.
 *
 * Usage:
 *   val proofJson = ProverNative.prove(
 *       wasmPath = "/data/data/.../files/circuits/transfer.wasm",
 *       zkeyPath = "/data/data/.../files/circuits/transfer_final.zkey",
 *       inputJson = """{"root":"...","nullifierHash":"...",...}"""
 *   )
 *   // proofJson is the standard snarkjs proof object:
 *   //   { "pi_a": ["...","...","1"], "pi_b": [["..","..","1"]],
 *   //     "pi_c": [...], "protocol":"groth16", "curve":"bn128" }
 *
 * The .wasm and .zkey artifacts must be downloaded from your backend
 * the first time the app runs and cached to internal storage. .zkey
 * files are typically 10-200 MB so should NOT be bundled in the APK.
 *
 * Origin of artifacts on the Atoshi project:
 *   /Users/liudongqi/atoshi/atoshi-privacy-circuits/build/transfer/
 *   /Users/liudongqi/atoshi/atoshi-privacy-circuits/build/unshield/
 */
object ProverNative {
    init {
        // rapidsnark depends on GMP; on Android both are bundled into one .so
        // by the upstream CMakeLists, so a single loadLibrary suffices.
        System.loadLibrary("rapidsnark")
    }

    /**
     * Generate a Groth16 proof.
     *
     * @param wasmPath  Absolute path to circuit witness-generator wasm.
     * @param zkeyPath  Absolute path to proving key (*.zkey).
     * @param inputJson JSON object with circuit signal names → field-element strings.
     *                  Public + private inputs combined; circuits/transfer.circom
     *                  expects keys like "root", "nullifierHash", "newCommitment",
     *                  plus private witness signals.
     * @return Proof JSON string (snarkjs-compatible).
     * @throws RuntimeException on prove failure.
     */
    @JvmStatic
    external fun prove(
        wasmPath: String,
        zkeyPath: String,
        inputJson: String
    ): String
}
