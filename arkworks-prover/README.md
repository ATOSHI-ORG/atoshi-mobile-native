# arkworks-prover (WIP — 暂不可用)

## ⚠️ 当前状态：依赖冲突，暂不可用

`ark-circom`（git master）依赖较新版本的 `ark-crypto-primitives`，与我们固定的
`ark-* = "0.5"` 不兼容，编译报错：

```
error[E0432]: unresolved import `ark_ff::SmallFp`
error[E0405]: cannot find trait `SmallFpConfig` in crate `ark_ff`
```

## 什么时候需要它

- **Week 1 Shield (明文→隐私)**：❌ **不需要**。Shield 只用 Poseidon, 不生成 ZK proof.
- Week 2 Unshield (隐私→明文)：需要
- Week 3 Transfer (隐私→隐私)：需要

所以 W1 安卓团队**不需要编这个**，先把 `../poseidon/` 编译 + Shield 集成跑通。

## 修复计划

W2 前（约 1 周内）解决以下之一：

1. Pin ark-circom 到一个特定 commit（已知与 ark-* 0.5 兼容）
2. 升级整个 ark-* 依赖到 0.6+，验证与 poseidon-rs 兼容
3. 切换到 [mopro](https://github.com/zkmopro/mopro) —— 已封装好 Android FFI

## W1 临时方案

`cd ../poseidon && ./build-android.sh` 即可。Shield 工作量集中在 Poseidon。

prover 相关待 W2 我修复后再启用。
