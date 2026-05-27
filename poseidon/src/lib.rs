//! Atoshi Poseidon hash — Android JNI + iOS C ABI.
//!
//! Computes circomlib-compatible Poseidon hash over BN254. Field elements
//! are passed as 32-byte big-endian byte arrays. Supported arity: 1..=16.

use ff_ce::PrimeField;
use num_bigint::BigInt;
use num_traits::Num;
use poseidon_rs::{Fr, Poseidon};

/// Convert a 32-byte big-endian buffer into a BN254 field element BigInt
/// expected by poseidon-rs.
fn buf_to_field(buf: &[u8]) -> Result<BigInt, String> {
    if buf.len() != 32 {
        return Err(format!("field element must be 32 bytes, got {}", buf.len()));
    }
    Ok(BigInt::from_bytes_be(num_bigint::Sign::Plus, buf))
}

/// Pad output to 32-byte big-endian.
fn field_to_buf(v: &BigInt) -> [u8; 32] {
    let (_, bytes) = v.to_bytes_be();
    let mut out = [0u8; 32];
    let start = 32 - bytes.len();
    out[start..].copy_from_slice(&bytes);
    out
}

/// Core hash function. Inputs is a slice of 32-byte field elements.
/// Returns 32 bytes (BE) of the hash output.
pub fn poseidon_hash(inputs: &[&[u8]]) -> Result<[u8; 32], String> {
    if inputs.is_empty() || inputs.len() > 16 {
        return Err(format!("arity must be 1..=16, got {}", inputs.len()));
    }

    // Convert 32-byte BE buffers → BigInt → decimal string → Fr.
    let fr_inputs: Vec<Fr> = inputs
        .iter()
        .map(|b| {
            let big = buf_to_field(b)?;
            let dec = big.to_str_radix(10);
            Fr::from_str(&dec).ok_or_else(|| format!("field element out of range: {}", dec))
        })
        .collect::<Result<Vec<_>, _>>()?;

    let poseidon = Poseidon::new();
    let out = poseidon
        .hash(fr_inputs)
        .map_err(|e| format!("poseidon error: {}", e))?;

    // poseidon-rs Fr Display: "Fr(0x29176100...)". Parse the hex out.
    let s = format!("{}", out);
    let inner = s
        .trim_start_matches("Fr(")
        .trim_end_matches(')')
        .trim_start_matches("0x");
    let big = BigInt::from_str_radix(inner, 16)
        .map_err(|e| format!("parse fr hex failed: {} (from {:?})", e, s))?;
    Ok(field_to_buf(&big))
}

// ============================================================================
// Android JNI
// ============================================================================

#[cfg(target_os = "android")]
mod android {
    use super::*;
    use jni::objects::{JByteArray, JClass, JObjectArray, JString};
    use jni::sys::{jbyteArray, jstring};
    use jni::JNIEnv;

    /// JNI signature (low-level, ByteArray API):
    ///   public static native byte[] hash(byte[][] inputs);
    /// Each input is a 32-byte big-endian field element.
    /// Returns 32-byte big-endian hash.
    #[no_mangle]
    pub extern "system" fn Java_xyz_atoshi_poseidon_PoseidonNative_hash<'local>(
        mut env: JNIEnv<'local>,
        _class: JClass<'local>,
        inputs: JObjectArray<'local>,
    ) -> jbyteArray {
        let result = (|| -> Result<Vec<u8>, String> {
            let len = env
                .get_array_length(&inputs)
                .map_err(|e| format!("get_array_length: {}", e))?;
            let mut bufs: Vec<Vec<u8>> = Vec::with_capacity(len as usize);
            for i in 0..len {
                let obj = env
                    .get_object_array_element(&inputs, i)
                    .map_err(|e| format!("get_object_array_element[{}]: {}", i, e))?;
                let ba: JByteArray = obj.into();
                let bytes = env
                    .convert_byte_array(&ba)
                    .map_err(|e| format!("convert_byte_array[{}]: {}", i, e))?;
                bufs.push(bytes);
            }
            let refs: Vec<&[u8]> = bufs.iter().map(|v| v.as_slice()).collect();
            let out = poseidon_hash(&refs)?;
            Ok(out.to_vec())
        })();

        match result {
            Ok(bytes) => env
                .byte_array_from_slice(&bytes)
                .map(|a| a.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            Err(msg) => {
                let _ = env.throw_new("java/lang/RuntimeException", msg);
                std::ptr::null_mut()
            }
        }
    }

    /// JNI signature (high-level, String-based API for ergonomic Kotlin use):
    ///   public static native String hashStrings(String[] decimalInputs);
    /// Each input is a decimal big-int string (e.g. "12345" or "0xabc...").
    /// Returns the hash as a decimal string. Easier than the byte[][] API.
    ///
    /// Usage in Kotlin:
    ///   val out = PoseidonNative.hashStrings(arrayOf(
    ///       amount.toString(),
    ///       tokenId.toString(),
    ///       owner.toString(),
    ///       blinding.toString(),
    ///   ))
    ///   val commitment = BigInteger(out)
    #[no_mangle]
    pub extern "system" fn Java_xyz_atoshi_poseidon_PoseidonNative_hashStrings<'local>(
        mut env: JNIEnv<'local>,
        _class: JClass<'local>,
        inputs: JObjectArray<'local>,
    ) -> jstring {
        let result = (|| -> Result<String, String> {
            let len = env
                .get_array_length(&inputs)
                .map_err(|e| format!("get_array_length: {}", e))?;
            let mut bufs: Vec<[u8; 32]> = Vec::with_capacity(len as usize);
            for i in 0..len {
                let obj = env
                    .get_object_array_element(&inputs, i)
                    .map_err(|e| format!("get_object_array_element[{}]: {}", i, e))?;
                let s: JString = obj.into();
                let rust_str: String = env
                    .get_string(&s)
                    .map_err(|e| format!("get_string[{}]: {}", i, e))?
                    .into();
                // Parse decimal OR 0x-prefixed hex
                let big = if let Some(hex) = rust_str.strip_prefix("0x").or_else(|| rust_str.strip_prefix("0X")) {
                    BigInt::from_str_radix(hex, 16)
                        .map_err(|e| format!("parse hex[{}]: {}", i, e))?
                } else {
                    BigInt::from_str_radix(&rust_str, 10)
                        .map_err(|e| format!("parse decimal[{}]: {}", i, e))?
                };
                bufs.push(field_to_buf(&big));
            }
            let refs: Vec<&[u8]> = bufs.iter().map(|b| &b[..]).collect();
            let out = poseidon_hash(&refs)?;
            // Return as decimal string (Java BigInteger(String) 默认按十进制解析)
            let big = BigInt::from_bytes_be(num_bigint::Sign::Plus, &out);
            Ok(big.to_str_radix(10))
        })();

        match result {
            Ok(s) => env
                .new_string(s)
                .map(|s| s.into_raw())
                .unwrap_or(std::ptr::null_mut()),
            Err(msg) => {
                let _ = env.throw_new("java/lang/RuntimeException", msg);
                std::ptr::null_mut()
            }
        }
    }
}

// ============================================================================
// iOS / generic C ABI
// ============================================================================

/// C ABI: compute Poseidon hash.
///
/// `inputs_ptr` points to N concatenated 32-byte field elements (so total
/// length = 32 * arity). `arity` must be 1..=16. Result is written into
/// `out_ptr` (32 bytes).
///
/// Returns 0 on success, negative on error.
///
/// # Safety
/// Caller must guarantee:
///   - inputs_ptr has at least 32 * arity readable bytes
///   - out_ptr has 32 writable bytes
#[no_mangle]
pub unsafe extern "C" fn atoshi_poseidon_hash(
    inputs_ptr: *const u8,
    arity: usize,
    out_ptr: *mut u8,
) -> i32 {
    if inputs_ptr.is_null() || out_ptr.is_null() {
        return -1;
    }
    if arity == 0 || arity > 16 {
        return -2;
    }
    let total = arity * 32;
    let slice = std::slice::from_raw_parts(inputs_ptr, total);
    let refs: Vec<&[u8]> = (0..arity)
        .map(|i| &slice[i * 32..(i + 1) * 32])
        .collect();

    match poseidon_hash(&refs) {
        Ok(out) => {
            std::ptr::copy_nonoverlapping(out.as_ptr(), out_ptr, 32);
            0
        }
        Err(_) => -3,
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn arity_two_known_vector() {
        // Test vector from circomlib: Poseidon([1, 2])
        let a = {
            let mut b = [0u8; 32];
            b[31] = 1;
            b
        };
        let b = {
            let mut b = [0u8; 32];
            b[31] = 2;
            b
        };
        let out = poseidon_hash(&[&a, &b]).unwrap();
        // Expected (decimal): 7853200120776062878684798364095072458815029376092732009249414926327459813530
        let hex = hex::encode(out);
        assert_eq!(
            hex,
            "115cc0f5e7d690413df64c6b9662e9cf2a3617f2743245519e19607a4417189a"
        );
    }
}
