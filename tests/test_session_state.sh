#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/common.sh"
source "$repo_root/lib/session-state.sh"

project_dir="$(mktemp -d)"

unset CLAUDE_HARK_HOME
assert_eq "$project_dir/.claude-hark/state.json" "$(state_path "$project_dir")"

state_init "$project_dir"
assert_eq '{}' "$(cat "$(state_path "$project_dir")")"

state_set_alias "$project_dir" "session-1" "deploy-watch" "manual"
assert_eq 'deploy-watch' "$(state_get_alias "$project_dir" "session-1")"
assert_eq 'deploy-watch' "$(state_resolve_alias "$project_dir" "session-1" "main")"

state_clear_alias "$project_dir" "session-1"
assert_eq '' "$(state_get_alias "$project_dir" "session-1")"

auto_alias="$(state_resolve_alias "$project_dir" "session-auto" "feature-x")"
assert_eq "$(basename "$project_dir"):feature-x" "$auto_alias"
assert_eq "$auto_alias" "$(state_get_alias "$project_dir" "session-auto")"
assert_eq 'auto' "$(jq -r '.sessions["session-auto"].alias.source' "$(state_path "$project_dir")")"

state_set_latest_action "$project_dir" "session-auto" "pre-tool-use" "Edit" "README.md" "准备修改 README" "fallback"
assert_eq '准备修改 README' "$(state_get_recent_action_summary "$project_dir" "session-auto" 120)"

old_time="$(python3 - <<'PY'
from datetime import datetime, timezone, timedelta
print((datetime.now(timezone.utc) - timedelta(seconds=300)).strftime('%Y-%m-%dT%H:%M:%SZ'))
PY
)"
tmp_file="$(mktemp)"
jq --arg old_time "$old_time" '.sessions["session-auto"].latestAction.updatedAt = $old_time' "$(state_path "$project_dir")" > "$tmp_file"
mv "$tmp_file" "$(state_path "$project_dir")"
assert_eq '' "$(state_get_recent_action_summary "$project_dir" "session-auto" 120)"

override_dir="$(mktemp -d)"
export CLAUDE_HARK_HOME="$override_dir/home"
assert_eq "$override_dir/home/state.json" "$(state_path "$project_dir")"
