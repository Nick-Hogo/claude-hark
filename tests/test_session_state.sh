#!/usr/bin/env bash
set -euo pipefail
# 这个测试脚本验证会话状态读写、别名和最近动作缓存行为。

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

state_set_description "$project_dir" "session-1" "Watching deploy progress" "manual"
assert_eq 'Watching deploy progress' "$(state_get_description "$project_dir" "session-1")"
state_clear_description "$project_dir" "session-1"
assert_eq '' "$(state_get_description "$project_dir" "session-1")"
state_should_generate_ai_alias "$project_dir" "session-guard" || fail 'empty alias source should allow ai generation'
state_set_alias "$project_dir" "session-guard" "auto-name" "auto"
state_should_generate_ai_alias "$project_dir" "session-guard" || fail 'auto alias source should allow ai generation'
state_set_alias "$project_dir" "session-guard" "ai-name" "ai"
if state_should_generate_ai_alias "$project_dir" "session-guard"; then fail 'ai alias source should block ai generation'; fi
state_set_alias "$project_dir" "session-guard" "manual-name" "manual"
if state_should_generate_ai_alias "$project_dir" "session-guard"; then fail 'manual alias source should block ai generation'; fi

auto_alias="$(state_resolve_alias "$project_dir" "session-auto" "feature-x")"
assert_eq "$(basename "$project_dir"):feature-x" "$auto_alias"
assert_eq "$auto_alias" "$(state_get_alias "$project_dir" "session-auto")"
assert_eq 'auto' "$(jq -r '.sessions["session-auto"].alias.source' "$(state_path "$project_dir")")"

display_json='{"kind":"permission","title":"权限申请：README.md","body":"权限申请：README.md"}'
state_set_latest_action "$project_dir" "session-auto" "pre-tool-use" "Edit" "README.md" "准备修改 README" "fallback" "$display_json"
assert_eq '准备修改 README' "$(state_get_recent_action_summary "$project_dir" "session-auto" 120)"
assert_eq 'recorded' "$(jq -r '.sessions["session-auto"].latestAction.status' "$(state_path "$project_dir")")"
assert_eq 'permission' "$(jq -r '.sessions["session-auto"].latestAction.display.kind' "$(state_path "$project_dir")")"

state_set_latest_action "$project_dir" "session-auto" "stop" "Claude" "turn" "Claude 已完成本轮响应" "fallback" "$display_json" "waiting_for_user"
assert_eq 'waiting_for_user' "$(jq -r '.sessions["session-auto"].latestAction.status' "$(state_path "$project_dir")")"
state_set_latest_action "$project_dir" "session-auto" "pre-tool-use" "Edit" "README.md" "准备修改 README" "fallback" "$display_json"

state_append_hook_event "$project_dir" "session-auto" "pre-tool-use" "Edit" "README.md" "准备修改 README" "fallback"
assert_eq '1' "$(state_get_hook_history_count "$project_dir" "session-auto")"
assert_eq 'pre-tool-use' "$(jq -r '.sessions["session-auto"].hookEvents[0].event' "$(state_path "$project_dir")")"
assert_eq 'README.md' "$(jq -r '.sessions["session-auto"].hookEvents[0].target' "$(state_path "$project_dir")")"
assert_eq '准备修改 README' "$(jq -r '.sessions["session-auto"].hookEvents[0].purpose' "$(state_path "$project_dir")")"
assert_eq 'recorded' "$(jq -r '.sessions["session-auto"].hookEvents[0].status' "$(state_path "$project_dir")")"

state_append_hook_event "$project_dir" "session-auto" "permission" "Edit" "README.md" "准备修改 README" "fallback" "更新 README 项目说明" "notified" "$display_json"
assert_eq '2' "$(state_get_hook_history_count "$project_dir" "session-auto")"
assert_eq 'permission' "$(jq -r '.sessions["session-auto"].hookEvents[1].event' "$(state_path "$project_dir")")"
assert_eq '更新 README 项目说明' "$(jq -r '.sessions["session-auto"].hookEvents[1].purpose' "$(state_path "$project_dir")")"
assert_eq 'notified' "$(jq -r '.sessions["session-auto"].hookEvents[1].status' "$(state_path "$project_dir")")"
assert_eq '权限申请：README.md' "$(jq -r '.sessions["session-auto"].hookEvents[1].display.title' "$(state_path "$project_dir")")"
assert_contains "$(state_get_hook_history "$project_dir" "session-auto")" '准备修改 README'

for i in $(seq 1 101); do
  state_append_hook_event "$project_dir" "session-cap" "pre-tool-use" "Edit" "file-$i" "summary-$i" "fallback"
done
assert_eq '100' "$(state_get_hook_history_count "$project_dir" "session-cap")"
assert_eq 'file-2' "$(jq -r '.sessions["session-cap"].hookEvents[0].target' "$(state_path "$project_dir")")"
assert_eq 'file-101' "$(jq -r '.sessions["session-cap"].hookEvents[99].target' "$(state_path "$project_dir")")"

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
