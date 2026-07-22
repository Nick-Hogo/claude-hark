#!/usr/bin/env bash
set -euo pipefail
# 这个测试脚本验证 claude-hark CLI 的 alias、doctor 和 dashboard 命令。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_HOME="$tmp_dir/home"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"
unset CLAUDE_HARK_SUMMARIZER_COMMAND CLAUDE_HARK_SESSION_NAMER_COMMAND

bash "$repo_root/bin/claude-hark" alias set session-1 deploy-watch
assert_eq 'deploy-watch' "$(bash "$repo_root/bin/claude-hark" alias get session-1)"
bash "$repo_root/bin/claude-hark" alias description-set session-1 'Watching deploy progress'
assert_eq 'Watching deploy progress' "$(bash "$repo_root/bin/claude-hark" alias describe session-1)"
assert_eq '' "$(bash "$repo_root/bin/claude-hark" alias description-clear session-1)"
assert_eq '' "$(bash "$repo_root/bin/claude-hark" alias describe session-1)"
assert_eq '' "$(bash "$repo_root/bin/claude-hark" alias clear session-1)"
assert_eq '' "$(bash "$repo_root/bin/claude-hark" alias get session-1)"

doctor_output="$(bash "$repo_root/bin/claude-hark" doctor)"
assert_contains "$doctor_output" 'jq: ok'
case "$doctor_output" in
  *'terminal-notifier: ok'*|*'osascript: ok'*) ;;
  *) fail "doctor did not report a macOS notifier backend: $doctor_output" ;;
esac
assert_contains "$doctor_output" 'state store: ok'
assert_contains "$doctor_output" 'summarizer: not configured (safe fallback only)'
assert_contains "$doctor_output" 'session namer: disabled'
assert_contains "$doctor_output" 'hook analysis: handler llm-first'

export CLAUDE_HARK_SUMMARIZER_COMMAND='stub-summarizer'
export CLAUDE_HARK_SESSION_NAMER_COMMAND='stub-namer'
doctor_output="$(bash "$repo_root/bin/claude-hark" doctor)"
assert_contains "$doctor_output" 'summarizer: configured'
assert_contains "$doctor_output" 'session namer: configured'
assert_contains "$doctor_output" 'hook analysis: handler llm-first'
