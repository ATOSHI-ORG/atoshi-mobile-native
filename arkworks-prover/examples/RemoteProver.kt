package xyz.atoshi.prover

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

/**
 * 临时 ZK Prover: 通过内网 HTTP 调 prove-server.
 *
 * ⚠️ 仅开发/测试期使用,witness 包含用户私钥.
 * 生产前必须替换成本地 .so prover (mopro/arkworks).
 *
 * 切换路径:
 *   现在:  val proof = RemoteProver.proveUnshield(witness)
 *   未来:  val proof = ProverNative.prove(wasmPath, zkeyPath, witness.toString())
 *   业务代码其他部分完全不变.
 *
 * 服务端启动: 在公司内网 Mac 跑:
 *   cd atoshi-privacy-contracts
 *   node scripts/prove-server.js
 *
 * 修改下面的 PROVE_SERVER_URL 为对应 Mac 的内网 IP:
 */
object RemoteProver {
    // ⚠️ 改成你们 prove server 的内网 IP
    private const val PROVE_SERVER_URL = "http://192.168.1.42:3000"

    private val client = OkHttpClient.Builder()
        .connectTimeout(10, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(60, TimeUnit.SECONDS)
        .build()

    private val JSON_MEDIA = "application/json; charset=utf-8".toMediaType()

    /**
     * 生成 Unshield (隐私→明文) 的 Groth16 proof.
     *
     * @param witness 电路所有 input signals 的 JSON
     *                必须包含 (按 unshield.circom 定义):
     *                public:  root, nullifierHash, recipient, tokenId, amount, fee
     *                private: privateKey, blinding, leafIndex, pathElements[], pathIndices[]
     * @return ProofResult 包含 pA / pB / pC 可直接传给 Solidity withdraw()
     */
    suspend fun proveUnshield(witness: JSONObject): ProofResult = withContext(Dispatchers.IO) {
        callProveEndpoint("/prove/unshield", witness)
    }

    /**
     * 生成 Transfer (隐私→隐私) 的 Groth16 proof.
     */
    suspend fun proveTransfer(witness: JSONObject): ProofResult = withContext(Dispatchers.IO) {
        callProveEndpoint("/prove/transfer", witness)
    }

    private fun callProveEndpoint(endpoint: String, witness: JSONObject): ProofResult {
        val body = JSONObject().put("witnessJson", witness).toString()
        val req = Request.Builder()
            .url("$PROVE_SERVER_URL$endpoint")
            .post(body.toRequestBody(JSON_MEDIA))
            .build()

        client.newCall(req).execute().use { resp ->
            if (!resp.isSuccessful) {
                throw RuntimeException(
                    "prove server HTTP ${resp.code}: ${resp.body?.string() ?: ""}"
                )
            }
            val json = JSONObject(resp.body!!.string())
            if (json.has("error")) {
                throw RuntimeException("prove server error: ${json.getString("error")}")
            }
            return ProofResult(
                pA = json.getJSONArray("pA"),
                pB = json.getJSONArray("pB"),
                pC = json.getJSONArray("pC"),
                publicSignals = json.getJSONArray("publicSignals"),
                elapsedMs = json.optLong("elapsedMs", 0L),
            )
        }
    }

    data class ProofResult(
        val pA: org.json.JSONArray,    // [x, y] for Solidity uint256[2]
        val pB: org.json.JSONArray,    // [[x1,x0],[y1,y0]] for Solidity uint256[2][2]
        val pC: org.json.JSONArray,    // [x, y] for Solidity uint256[2]
        val publicSignals: org.json.JSONArray,
        val elapsedMs: Long,
    )
}
