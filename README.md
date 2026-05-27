# atoshi-mobile-native

> Native Android / iOS components for Atoshi privacy transactions.

[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![Platforms](https://img.shields.io/badge/platform-Android%20%7C%20iOS-lightgrey)]()

Two native libraries that mobile wallets need in order to perform
**Shield / Transfer / Unshield** privacy operations on the Atoshi L2 chain.
Without these, mobile clients can't compute Poseidon hashes or generate
Groth16 proofs locally on-device.

---

## What's in this repo

| Module | What it does | License | Required for |
|---|---|---|---|
| [`poseidon/`](./poseidon) | BN254-Poseidon hash | Apache-2.0 ✅ | **All** privacy ops |
| [`arkworks-prover/`](./arkworks-prover) | Groth16 ZK prover (license-friendly) | Apache-2.0 / MIT ✅ | Transfer + Unshield (**production**) |
| [`rapidsnark/`](./rapidsnark) | Groth16 ZK prover (fast, GPL) | GPL-3.0 ⚠️ | Transfer + Unshield (open-source apps only) |

> **Shield (plaintext → private) does NOT need any prover** — only Poseidon.
> First-week mobile integration can ship with `poseidon/` alone.
>
> ### Which prover to choose?
>
> | Your app | Use |
> |---|---|
> | Closed-source / commercial | **`arkworks-prover/`** (Apache-2.0/MIT) |
> | Open-source (GPL-compatible) | `rapidsnark/` (faster) |
> | Don't know yet | `arkworks-prover/` — switching later is trivial (same Kotlin API) |
>
> Performance comparison (flagship Android, transfer.circom):
> - rapidsnark:        ~5s
> - arkworks-prover:   ~10-15s
> Both acceptable for wallet UX (one-time per privacy tx).

---

## Quick start (Android)

```bash
# 1. Install Rust toolchain + Android targets
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup target add aarch64-linux-android armv7-linux-androideabi i686-linux-android x86_64-linux-android
cargo install cargo-ndk

# 2. Point at your Android NDK (r25c+)
export ANDROID_NDK_HOME=$HOME/Library/Android/sdk/ndk/25.2.9519653

# 3. Build Poseidon → 4 .so files
cd poseidon
./build-android.sh

# Output: poseidon/jniLibs/{arm64-v8a,armeabi-v7a,x86,x86_64}/libatoshi_poseidon.so
```

Drop the `.so` files into your Android project at `app/src/main/jniLibs/`,
copy `poseidon/examples/PoseidonNative.kt` to `app/src/main/java/xyz/atoshi/poseidon/`,
then call:

```kotlin
import xyz.atoshi.poseidon.PoseidonNative

// commitment = Poseidon(amount, tokenId, owner, blinding)
val commitment = PoseidonNative.hash(amount, tokenId, owner, blinding)

// nullifier = Poseidon(commitment, privateKey, leafIndex)
val nullifier = PoseidonNative.hash(commitment, privateKey, leafIndex)
```

For Transfer / Unshield (Week 2+), see [`rapidsnark/README.md`](./rapidsnark).

For iOS, see `build-ios.sh` in each module.

---

## Architecture

```
┌─────────────────────────────┐
│  Mobile Wallet App          │
│  (Kotlin / Swift)           │
└──────────────┬──────────────┘
               │
        ┌──────┼──────┐
        ▼             ▼
┌──────────────┐  ┌──────────────────┐
│  Poseidon    │  │  rapidsnark      │
│  (this repo) │  │  (this repo)     │
│              │  │                  │
│  ~1 ms hash  │  │  ~5-30 s proof   │
└──────────────┘  └────────┬─────────┘
                           │ reads
                           ▼
                  ┌──────────────────┐
                  │  Circuit assets  │
                  │  (.wasm + .zkey) │
                  │                  │
                  │  Distributed via │
                  │  your CDN. From: │
                  │  atoshi-privacy- │
                  │  circuits repo   │
                  └──────────────────┘
                           │
                           ▼
                  ┌──────────────────┐
                  │  Atoshi L2 chain │
                  │  Shield contract │
                  └──────────────────┘
```

---

## Build matrix

| Target | Module | Output | Build script |
|---|---|---|---|
| Android arm64-v8a | poseidon | `libatoshi_poseidon.so` | `poseidon/build-android.sh` |
| Android armeabi-v7a | poseidon | `libatoshi_poseidon.so` | (same) |
| Android x86 | poseidon | `libatoshi_poseidon.so` | (same) |
| Android x86_64 | poseidon | `libatoshi_poseidon.so` | (same) |
| iOS device + simulator | poseidon | `AtoshiPoseidon.xcframework` | `poseidon/build-ios.sh` |
| Android arm64-v8a / v7a / x86_64 | rapidsnark | `librapidsnark.so` | `rapidsnark/build-android.sh` |
| iOS device + simulator | rapidsnark | `Rapidsnark.xcframework` | `rapidsnark/build-ios.sh` |

---

## Prerequisites

| Tool | Used by | Install |
|---|---|---|
| Rust 1.70+ | Poseidon | `curl https://sh.rustup.rs -sSf \| sh` |
| Android NDK r25c+ | both | Install via Android Studio (SDK Manager → SDK Tools → NDK), or [direct download](https://developer.android.com/ndk/downloads) |
| `cargo-ndk` | Poseidon | `cargo install cargo-ndk` |
| `cmake` 3.20+ | rapidsnark | `brew install cmake` / `apt install cmake` |
| `nasm` | rapidsnark (x86_64) | `brew install nasm` / `apt install nasm` |
| Xcode 14+ | iOS builds | App Store |
| `git` | rapidsnark | preinstalled on macOS |

---

## Mobile integration checklist

- [ ] Build artifacts placed under `app/src/main/jniLibs/<ABI>/`
- [ ] Kotlin/Swift bridge files at correct package (`xyz.atoshi.poseidon` etc.)
- [ ] App Bundle (AAB) enabled to ship per-architecture binaries to users
- [ ] `.wasm` + `.zkey` artifacts hosted on CDN, downloaded on first app launch
- [ ] SHA-256 integrity check on downloaded `.zkey` files
- [ ] Proof generation runs on a background thread (proof takes 5-30s on mobile)
- [ ] No witness data (which contains private keys) ever leaves the device

---

## How proof generation flows on-device

```
User taps "Send" in wallet
        ↓
App selects an old Note (commitment + blinding + privateKey)
        ↓
App fetches current Merkle root from Shield contract (RPC)
        ↓
App computes Merkle path locally
        ↓
App calls Poseidon (this repo) to compute nullifier
        ↓
App assembles witness JSON
        ↓
App calls rapidsnark (this repo) → generates Groth16 proof
   (this is the slow step: 5-30s)
        ↓
App submits L2 tx: Shield.transfer(pA, pB, pC, root, nullifier, newCommitment)
        ↓
On-chain TransferVerifier.verifyProof() returns true
        ↓
Old note nullified, new note minted
```

---

## Where the circuit assets come from

The `.wasm` and `.zkey` files referenced above are **not** in this repo.
They're built once from the source circuits in:

```
https://github.com/atoshi-chain/atoshi-privacy-circuits
```

After running `npm run build` in that repo, you get:

```
build/
├── transfer/
│   ├── transfer.wasm
│   └── transfer_final.zkey
└── unshield/
    ├── unshield.wasm
    └── unshield_final.zkey
```

Host these on your CDN and have the mobile app download + cache them on first launch.

---

## Testing

```bash
# Unit tests for Poseidon hash output
cd poseidon
cargo test
```

Should pass — verifies against the known circomlib test vector
`Poseidon([1, 2]) = 0x115cc0f5e7d690413df64c6b9662e9cf2a3617f2743245519e19607a4417189a`.

---

## Security considerations

1. **Private keys never leave the device.** Witness data passed to rapidsnark
   contains private keys; the entire proof flow must run on-device. Do not
   build a "prove-as-a-service" backend for production.
2. **`.zkey` integrity.** A malicious `.zkey` could generate proofs that pass
   verification but reveal information. Pin SHA-256 of each `.zkey` in app
   code and reject downloads that don't match.
3. **`.so` integrity.** Android APKs can be repacked. Use Play Integrity API
   or App Attest to detect tampering in production builds.
4. **Side-channel.** Proof generation time and CPU patterns may leak some
   information. Acceptable for current threat model; revisit for hardened
   threat model (e.g. nation-state).

---

## Repository layout

```
.
├── README.md                       ← This file
├── LICENSE                         ← Apache-2.0
├── .gitignore
│
├── poseidon/
│   ├── Cargo.toml
│   ├── src/lib.rs                  ← Rust: poseidon-rs wrapper + JNI + C ABI
│   ├── build-android.sh
│   ├── build-ios.sh
│   └── examples/
│       ├── PoseidonNative.kt
│       └── PoseidonNative.swift
│
└── rapidsnark/
    ├── build-android.sh            ← Clones iden3/rapidsnark + cross-compiles
    ├── build-ios.sh
    └── examples/
        ├── ProverNative.kt
        └── jni_wrapper.cpp         ← JNI bridge from Kotlin to rapidsnark C++ API
```

---

## License

Apache-2.0 — see [LICENSE](LICENSE).

Built on top of open-source components:

- [iden3/poseidon-rs](https://github.com/iden3/poseidon-rs) (Apache-2.0)
- [iden3/rapidsnark](https://github.com/iden3/rapidsnark) (GPL-3.0 — note: imposes
  copyleft requirements on consumers of `librapidsnark.so`. Review carefully
  before shipping a closed-source app, or use the rapidsnark fork with
  permissive license.)

---

## Maintainers

- [@maoaixiao1314](https://github.com/maoaixiao1314)

For questions, open an [issue](../../issues).
