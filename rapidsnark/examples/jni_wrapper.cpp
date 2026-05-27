// JNI wrapper template — bridges xyz.atoshi.prover.ProverNative.prove()
// to rapidsnark's witness generator + Groth16 prover.
//
// Build this file together with rapidsnark's libraries. See ../build-android.sh
// for the Android build pipeline; this wrapper is compiled as part of the
// final librapidsnark.so via an addition to rapidsnark's CMakeLists.txt:
//
//     add_library(rapidsnark SHARED
//         ${RAPIDSNARK_SOURCES}
//         ${CMAKE_CURRENT_SOURCE_DIR}/../examples/jni_wrapper.cpp)
//     target_link_libraries(rapidsnark gmp)
//
// Java/Kotlin caller — see ProverNative.kt.

#include <jni.h>
#include <string>
#include <vector>
#include <fstream>
#include <sstream>
#include <stdexcept>

// Forward-declare rapidsnark's C-style prover API. The actual prototypes live
// in <rapidsnark/prover.hpp>; adjust the include path to your build output.
extern "C" {
    // Generates a witness from inputJson using the wasm at wasmPath.
    // Returns 0 on success.
    int witnesscalc_run(const char* wasm_path,
                        const char* input_json,
                        unsigned char* wtns_buf,
                        unsigned long* wtns_size);

    // Generates a Groth16 proof from witness + zkey.
    // Writes proof JSON into proof_buf (caller allocates).
    int groth16_prover(const void* zkey_data, unsigned long zkey_size,
                       const void* wtns_data, unsigned long wtns_size,
                       char* proof_buf, unsigned long* proof_size,
                       char* public_buf, unsigned long* public_size,
                       char* error_msg, unsigned long error_msg_max);
}

static std::vector<unsigned char> read_file(const std::string& path) {
    std::ifstream f(path, std::ios::binary | std::ios::ate);
    if (!f) throw std::runtime_error("cannot open: " + path);
    auto size = f.tellg();
    f.seekg(0);
    std::vector<unsigned char> buf(static_cast<size_t>(size));
    f.read(reinterpret_cast<char*>(buf.data()), size);
    return buf;
}

extern "C" JNIEXPORT jstring JNICALL
Java_xyz_atoshi_prover_ProverNative_prove(
    JNIEnv* env, jclass /*clazz*/,
    jstring jWasmPath, jstring jZkeyPath, jstring jInputJson)
{
    const char* wasmPath  = env->GetStringUTFChars(jWasmPath, nullptr);
    const char* zkeyPath  = env->GetStringUTFChars(jZkeyPath, nullptr);
    const char* inputJson = env->GetStringUTFChars(jInputJson, nullptr);

    auto cleanup = [&]() {
        env->ReleaseStringUTFChars(jWasmPath, wasmPath);
        env->ReleaseStringUTFChars(jZkeyPath, zkeyPath);
        env->ReleaseStringUTFChars(jInputJson, inputJson);
    };

    try {
        // 1. Witness generation.
        std::vector<unsigned char> wtns(8 * 1024 * 1024);   // 8 MB scratch
        unsigned long wtns_size = wtns.size();
        if (witnesscalc_run(wasmPath, inputJson, wtns.data(), &wtns_size) != 0) {
            cleanup();
            env->ThrowNew(env->FindClass("java/lang/RuntimeException"),
                          "witness calc failed");
            return nullptr;
        }

        // 2. Load zkey.
        auto zkey = read_file(zkeyPath);

        // 3. Groth16 prove.
        std::string proof_out(64 * 1024, '\0');
        std::string public_out(64 * 1024, '\0');
        std::string err(1024, '\0');
        unsigned long proof_size = proof_out.size();
        unsigned long public_size = public_out.size();
        int rc = groth16_prover(zkey.data(), zkey.size(),
                                wtns.data(), wtns_size,
                                proof_out.data(), &proof_size,
                                public_out.data(), &public_size,
                                err.data(), err.size());
        if (rc != 0) {
            cleanup();
            std::string msg = "groth16 prove failed: " + err;
            env->ThrowNew(env->FindClass("java/lang/RuntimeException"), msg.c_str());
            return nullptr;
        }

        proof_out.resize(proof_size);
        cleanup();
        return env->NewStringUTF(proof_out.c_str());

    } catch (const std::exception& e) {
        cleanup();
        env->ThrowNew(env->FindClass("java/lang/RuntimeException"), e.what());
        return nullptr;
    }
}
