#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  [[ "$expected" == "$actual" ]] || fail "expected [$expected] got [$actual]"
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || fail "expected [$haystack] to contain [$needle]"
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || fail "expected [$haystack] not to contain [$needle]"
}
