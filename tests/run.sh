#!/bin/bash
# tests/run.sh — 纯解析单元测试（无需真实硬件/BetterDisplay）。
# 用 fixture 喂给 parse_sidecar_uuid / parse_builtin_uuid，断言输出 UUID。
# 同时覆盖 awk 兜底路径与 jq 路径（若 CI 装了 jq）。
set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
# shellcheck source=/dev/null
source "$ROOT/src/common.sh"

FIX="$DIR/fixtures/identifiers.txt"
EXP_SIDECAR="22222222-AAAA-BBBB-CCCC-000000000002"
EXP_BUILTIN="33333333-AAAA-BBBB-CCCC-000000000003"

fail=0
check(){ # desc expected actual
  if [ "$2" = "$3" ]; then
    printf 'PASS  %-16s %s\n' "$1" "$3"
  else
    printf 'FAIL  %-16s expected=%s actual=%s\n' "$1" "$2" "$3"; fail=1
  fi
}

echo "== awk 兜底路径 =="
have_jq(){ return 1; }
check "awk sidecar" "$EXP_SIDECAR" "$(parse_sidecar_uuid < "$FIX")"
check "awk builtin" "$EXP_BUILTIN" "$(parse_builtin_uuid < "$FIX")"

if command -v jq >/dev/null 2>&1; then
  echo "== jq 路径 =="
  have_jq(){ return 0; }
  check "jq sidecar" "$EXP_SIDECAR" "$(parse_sidecar_uuid < "$FIX")"
  check "jq builtin" "$EXP_BUILTIN" "$(parse_builtin_uuid < "$FIX")"
else
  echo "(未装 jq，跳过 jq 路径测试)"
fi

echo
[ "$fail" -eq 0 ] && echo "全部通过 ✅" || echo "存在失败 ❌"
exit "$fail"
