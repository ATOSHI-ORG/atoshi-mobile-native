package xyz.atoshi.poseidon

import java.math.BigInteger

/**
 * Native JNI bridge to libatoshi_poseidon.so.
 *
 * Setup:
 *   1. Run ../build-android.sh — outputs jniLibs/<abi>/libatoshi_poseidon.so
 *   2. Copy jniLibs/ into your Android project: app/src/main/jniLibs/
 *   3. Place this file in app/src/main/java/xyz/atoshi/poseidon/PoseidonNative.kt
 *      (the package path xyz.atoshi.poseidon is hard-coded in the JNI symbol name)
 *
 * Usage:
 *   val commitment = PoseidonNative.hash(amount, tokenId, owner, blinding)
 *   val nullifier  = PoseidonNative.hash(commitment, privateKey, leafIndex)
 */
object PoseidonNative {
    init {
        System.loadLibrary("atoshi_poseidon")
    }

    /**
     * Low-level API. Compute Poseidon hash over N inputs (1..=16).
     *
     * @param inputs Array of 32-byte big-endian field elements.
     * @return 32-byte big-endian hash output.
     */
    @JvmStatic
    external fun hash(inputs: Array<ByteArray>): ByteArray

    /**
     * High-level API for ergonomic Kotlin use.
     * Pass decimal big-int strings (or "0x..." hex strings), returns decimal string.
     *
     * Usage:
     *   val out = PoseidonNative.hashStrings(arrayOf(
     *       amount.toString(),      // "1000000000000000000"
     *       tokenId.toString(),     // "0"
     *       owner.toString(),       // "12345..."
     *       blinding.toString(),    // "67890..."
     *   ))
     *   val commitment = BigInteger(out)
     */
    @JvmStatic
    external fun hashStrings(inputs: Array<String>): String

    /**
     * Convenience: take BigInteger inputs (must be < BN254 scalar field size),
     * encode them to 32-byte BE buffers, hash, and return the result as BigInteger.
     * Internally uses the ByteArray API.
     */
    fun hash(vararg fields: BigInteger): BigInteger {
        require(fields.isNotEmpty() && fields.size <= 16) {
            "Poseidon arity must be 1..=16, got ${fields.size}"
        }
        val bufs = Array(fields.size) { i -> toBe32(fields[i]) }
        val out = hash(bufs)
        return BigInteger(1, out)
    }

    /** Big-endian, zero-padded to 32 bytes. */
    private fun toBe32(v: BigInteger): ByteArray {
        require(v.signum() >= 0) { "negative not allowed" }
        val raw = v.toByteArray()
        // raw may have a leading 0x00 sign byte or be shorter than 32 bytes
        val out = ByteArray(32)
        val start = if (raw.size > 32) raw.size - 32 else 0
        val len = minOf(raw.size, 32)
        System.arraycopy(raw, start, out, 32 - len, len)
        return out
    }
}
