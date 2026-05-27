import Foundation

/// Native bridge to AtoshiPoseidon.xcframework (libatoshi_poseidon.a).
///
/// Setup:
///   1. Run ../build-ios.sh — outputs AtoshiPoseidon.xcframework + include/atoshi_poseidon.h
///   2. Drag AtoshiPoseidon.xcframework into Xcode (Embed & Sign).
///   3. Add include/atoshi_poseidon.h to a Swift bridging header:
///         #import "atoshi_poseidon.h"
///
/// Usage:
///   let commitment = try PoseidonNative.hash([amount, tokenId, owner, blinding])
///   let nullifier  = try PoseidonNative.hash([commitment, privateKey, leafIndex])
public enum PoseidonError: Error {
    case invalidArity
    case hashFailed(Int32)
}

public enum PoseidonNative {
    /// Compute Poseidon hash over N 32-byte field elements (1..=16).
    public static func hash(_ inputs: [Data]) throws -> Data {
        guard !inputs.isEmpty, inputs.count <= 16 else {
            throw PoseidonError.invalidArity
        }
        for buf in inputs where buf.count != 32 {
            throw PoseidonError.invalidArity
        }

        var packed = Data(capacity: 32 * inputs.count)
        for buf in inputs { packed.append(buf) }

        var out = Data(count: 32)
        let status = packed.withUnsafeBytes { (inPtr: UnsafeRawBufferPointer) -> Int32 in
            out.withUnsafeMutableBytes { (outPtr: UnsafeMutableRawBufferPointer) -> Int32 in
                atoshi_poseidon_hash(
                    inPtr.bindMemory(to: UInt8.self).baseAddress,
                    inputs.count,
                    outPtr.bindMemory(to: UInt8.self).baseAddress
                )
            }
        }
        guard status == 0 else {
            throw PoseidonError.hashFailed(status)
        }
        return out
    }
}
