#!/usr/bin/env bash
set -euo pipefail
# 这个测试辅助脚本提供断言函数，供 shell 测试复用。

# 输出失败信息并结束当前测试。
fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

# 断言两个字符串完全相等。
assert_eq() {
  local expected="$1"
  local actual="$2"
  [[ "$expected" == "$actual" ]] || fail "expected [$expected] got [$actual]"
}

# 断言字符串包含指定片段。
assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected [$haystack] to contain [$needle]"
}

# 断言字符串不包含指定片段。
assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected [$haystack] not to contain [$needle]"
}
