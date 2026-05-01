#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_HOME="$tmp_dir/home"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

bash "$repo_root/bin/claude-hark" alias set session-1 deploy-watch
assert_eq 'deploy-watch' "$(bash "$repo_root/bin/claude-hark" alias get session-1)"
assert_eq '' "$(bash "$repo_root/bin/claude-hark" alias clear session-1)"
assert_eq '' "$(bash "$repo_root/bin/claude-hark" alias get session-1)"

doctor_output="$(bash "$repo_root/bin/claude-hark" doctor)"
assert_contains "$doctor_output" 'jq: ok'
assert_contains "$doctor_output" 'osascript: ok'
assert_contains "$doctor_output" 'state store: ok'
assert_contains "$doctor_output" 'summarizer: fallback rules'

export CLAUDE_HARK_SUMMARIZER_COMMAND='stub-summarizer'
doctor_output="$(bash "$repo_root/bin/claude-hark" doctor)"
assert_contains "$doctor_output" 'summarizer: configured'
