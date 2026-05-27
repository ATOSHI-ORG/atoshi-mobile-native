#!/usr/bin/env bash
# ============================================================================
# 试找一个能编通的 ark-circom commit
#
# 用户给的 10 个 commit, 按"老到新"顺序试 (老的更可能用 ark-* 0.4):
#
# 用法:
#   cd atoshi-mobile-native/arkworks-prover
#   ./try-commits.sh
#
# 找到能用的会自动把那个 commit 写进 Cargo.toml. 之后跑 ./build-android.sh.
# ============================================================================
set -uo pipefail
cd "$(dirname "$0")"

# 老到新
COMMITS=(
  "4d99060fce7817c56300e2dce16ec54a87ad9f66"  # 2024-07-18
  "967add46da8ece5216f1838233043ccc9c511330"  # 2024-07-18
  "fa6262ab5874772b8534f16812617c5ab7de5c3e"  # 2024-07-18
  "a573c15b32a8e20ceaa5fb8c8dac9826ecc5872c"  # 2024-07-18
  "dbc38c59af921bc044fdbfa89bff3627571be8b6"  # 2024-10-26
  "89b1327a18b4762d04dede178b43fdef8852171e"  # 2024-10-26
  "7f80002b525c0ebc96b18fb1edcd731e4e4dd679"  # 2024-10-26
  "3c95ed98e23a408b4d99a53e483a9bba39685a4e"  # 2025-02-25
  "7344c758f5aaa7292eadb12b9b57b104afe86100"  # 2025-08-15
  "09e92d4c5887cec9ea558dc7e775a8ab3b02aafc"  # 2025-08-27
)

# 备份
cp Cargo.toml Cargo.toml.bak

for commit in "${COMMITS[@]}"; do
  echo
  echo "════════════════════════════════════════════════════════════"
  echo " 试 commit: $commit"
  echo "════════════════════════════════════════════════════════════"

  # 把 Cargo.toml 里的 rev = "..." 替换成当前 commit
  sed -E "s|rev = \"[a-f0-9]+\"|rev = \"$commit\"|" Cargo.toml.bak > Cargo.toml

  # 清掉 lock 文件,强制重新解析
  rm -f Cargo.lock
  rm -rf target

  if cargo check 2>&1 | tee /tmp/cargo-try.log | tail -20; then
    if ! grep -qE "error\[E[0-9]+\]|error: " /tmp/cargo-try.log; then
      echo
      echo "✓✓✓ commit $commit 编译通过! ✓✓✓"
      echo
      echo "Cargo.toml 已锁定到这个 commit. 现在可以跑:"
      echo "  ./build-android.sh"
      exit 0
    fi
  fi
  echo "✗ commit $commit 失败"
done

echo
echo "════════════════════════════════════════════════════════════"
echo " 全部 ${#COMMITS[@]} 个 commit 都失败"
echo "════════════════════════════════════════════════════════════"
echo
echo "建议切换到 mopro: https://github.com/zkmopro/mopro"
echo "或者今晚走 prove-server 临时方案."
echo
# 恢复原 Cargo.toml
cp Cargo.toml.bak Cargo.toml
exit 1
