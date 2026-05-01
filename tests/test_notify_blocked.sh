#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

project_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$project_dir/notify.log"

permission_payload='{"session_id":"session-12345678","tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"'$project_dir'"}'
permission_output="$(printf '%s' "$permission_payload" | bash "$repo_root/hooks/notify-blocked.sh" permission)"
project_alias="$(basename "$project_dir")"
assert_eq "Claude Code|[$project_alias] 等待权限：Bash；目的：运行验证命令确认当前结果" "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
assert_eq "{\"systemMessage\":\"[$project_alias] 等待权限：Bash；目的：运行验证命令确认当前结果\"}" "$permission_output"
