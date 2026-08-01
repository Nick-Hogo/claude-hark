#!/usr/bin/env bash
set -euo pipefail
# 这个测试脚本验证 Claude Code hook 事件到状态和通知的完整流程。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

project_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$project_dir/notify.log"
export CLAUDE_HARK_NOW='12:34:56'

stub="$project_dir/summarizer.sh"
cat > "$stub" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
input="$(cat)"
if printf '%s' "$input" | grep -q '<event>permission</event>'; then
  printf '{"title":"LLM权限分析","summary":"准备调整 README 的项目定位说明","purpose":"权限审批","details":["检查 README.md 的编辑权限"],"suggestion":"确认 diff 后再授权","review":["目标文件是否正确"],"nextAction":"批准后查看修改结果"}'
elif printf '%s' "$input" | grep -q '<event>elicitation</event>'; then
  printf '{"title":"等待用户选择","summary":"请选择下一步通知样式","purpose":"用户决策","details":["需要用户补充选择"],"suggestion":"回到 Claude 会话选择","review":["确认选项影响"],"nextAction":"选择一个通知样式"}'
elif printf '%s' "$input" | grep -q '<event>stop</event>'; then
  printf '{"title":"本轮完成","summary":"本轮已完成 hook 流程记录","purpose":"等待下一步指示","details":["最近事件已写入状态"],"suggestion":"查看 dashboard 卡片","review":["确认结果是否符合预期"],"nextAction":"继续给出下一步"}'
else
  printf '{"title":"LLM事件分析","summary":"准备调整 README 的项目定位说明","purpose":"推进当前任务","details":["分析当前 hook 事件"],"suggestion":"继续观察结果","review":["确认操作范围"],"nextAction":"等待下一步"}'
fi
SH
chmod +x "$stub"
export CLAUDE_HARK_SUMMARIZER_COMMAND="$stub"

namer_stub="$project_dir/namer.sh"
cat > "$namer_stub" <<'SH'
#!/usr/bin/env bash
cat > "$CLAUDE_HARK_NAMER_CALLED"
printf '{"name":"readme-session","description":"Updating README content for the current task."}\n'
SH
chmod +x "$namer_stub"
export CLAUDE_HARK_SESSION_NAMER_COMMAND="$namer_stub"
export CLAUDE_HARK_NAMER_CALLED="$project_dir/namer-called.json"

pre_tool_payload='{"session_id":"session-edit-1234","tool_name":"Edit","tool_input":{"file_path":"'$project_dir'/README.md","old_string":"old","new_string":"new"},"cwd":"'$project_dir'"}'
pre_tool_output="$(printf '%s' "$pre_tool_payload" | bash "$repo_root/hooks/claude-hark.sh" pre-tool-use)"
assert_eq '' "$pre_tool_output"
assert_eq '准备调整 README 的项目定位说明' "$(jq -r '.sessions["session-edit-1234"].latestAction.summary' "$project_dir/.claude-hark/state.json")"
assert_eq 'README.md' "$(jq -r '.sessions["session-edit-1234"].latestAction.target' "$project_dir/.claude-hark/state.json")"
assert_eq '1' "$(jq -r '.sessions["session-edit-1234"].hookEvents | length' "$project_dir/.claude-hark/state.json")"
assert_eq 'pre-tool-use' "$(jq -r '.sessions["session-edit-1234"].hookEvents[0].event' "$project_dir/.claude-hark/state.json")"
assert_eq 'active' "$(jq -r '.sessions["session-edit-1234"].latestAction.status' "$project_dir/.claude-hark/state.json")"
assert_eq 'active' "$(jq -r '.sessions["session-edit-1234"].hookEvents[0].status' "$project_dir/.claude-hark/state.json")"
assert_eq 'pre-tool-use' "$(jq -r '.sessions["session-edit-1234"].hookEvents[0].display.kind' "$project_dir/.claude-hark/state.json")"
assert_contains "$(jq -r '.sessions["session-edit-1234"].hookEvents[0].purpose' "$project_dir/.claude-hark/state.json")" '<event>pre-tool-use</event>'
assert_eq 'readme-session' "$(jq -r '.sessions["session-edit-1234"].alias.value' "$project_dir/.claude-hark/state.json")"
assert_eq 'ai' "$(jq -r '.sessions["session-edit-1234"].alias.source' "$project_dir/.claude-hark/state.json")"
assert_eq 'Updating README content for the current task.' "$(jq -r '.sessions["session-edit-1234"].description.value' "$project_dir/.claude-hark/state.json")"
assert_contains "$(cat "$CLAUDE_HARK_NAMER_CALLED")" '"target": "README.md"'

large_payload_file="$project_dir/large-payload.json"
PROJECT_DIR="$project_dir" python3 - <<'PY' > "$large_payload_file"
import json
import os

project_dir = os.environ["PROJECT_DIR"]
payload = {
    "session_id": "session-large-payload",
    "tool_name": "Bash",
    "tool_input": {"command": "printf '%s' " + "x" * 140000},
    "cwd": project_dir,
}
print(json.dumps(payload, separators=(",", ":")), end="")
PY
[[ "$(wc -c < "$large_payload_file")" -gt 131072 ]] || fail 'large payload should exceed Linux MAX_ARG_STRLEN'
rm -f "$CLAUDE_HARK_NAMER_CALLED"
large_pre_tool_output="$(bash "$repo_root/hooks/claude-hark.sh" pre-tool-use < "$large_payload_file")"
assert_eq '' "$large_pre_tool_output"
assert_eq 'Bash' "$(jq -r '.sessions["session-large-payload"].latestAction.toolName' "$project_dir/.claude-hark/state.json")"
assert_eq 'pre-tool-use' "$(jq -r '.sessions["session-large-payload"].latestAction.event' "$project_dir/.claude-hark/state.json")"
assert_eq 'readme-session' "$(jq -r '.sessions["session-large-payload"].alias.value' "$project_dir/.claude-hark/state.json")"
[[ -s "$CLAUDE_HARK_NAMER_CALLED" ]] || fail 'large payload namer input not captured'

permission_edit_payload='{"session_id":"session-edit-1234","tool_name":"Edit","tool_input":{"file_path":"'$project_dir'/README.md"},"cwd":"'$project_dir'"}'
permission_edit_output="$(printf '%s' "$permission_edit_payload" | bash "$repo_root/hooks/claude-hark.sh" permission)"
project_alias='readme-session'
[[ -s "$CLAUDE_HARK_NOTIFY_STUB" ]] || fail 'permission notification not written'
assert_eq "{\"systemMessage\":\"[$project_alias] 等待权限：Edit；目的：准备调整 README 的项目定位说明\"}" "$permission_edit_output"
assert_eq '2' "$(jq -r '.sessions["session-edit-1234"].hookEvents | length' "$project_dir/.claude-hark/state.json")"
assert_eq 'permission' "$(jq -r '.sessions["session-edit-1234"].hookEvents[1].event' "$project_dir/.claude-hark/state.json")"
assert_eq '准备调整 README 的项目定位说明' "$(jq -r '.sessions["session-edit-1234"].hookEvents[1].summary' "$project_dir/.claude-hark/state.json")"
assert_contains "$(jq -r '.sessions["session-edit-1234"].hookEvents[1].purpose' "$project_dir/.claude-hark/state.json")" '<event>permission</event>'
assert_eq 'notified' "$(jq -r '.sessions["session-edit-1234"].hookEvents[1].status' "$project_dir/.claude-hark/state.json")"
assert_eq 'permission' "$(jq -r '.sessions["session-edit-1234"].latestAction.display.kind' "$project_dir/.claude-hark/state.json")"
assert_contains "$(jq -r '.sessions["session-edit-1234"].latestAction.display.aiInput' "$project_dir/.claude-hark/state.json")" '<event>permission</event>'
[[ -n "$(jq -r '.sessions["session-edit-1234"].hookEvents[1].display.renderedBody' "$project_dir/.claude-hark/state.json")" ]] || fail 'permission rendered body should be stored'

manual_payload='{"session_id":"session-manual","tool_name":"Edit","tool_input":{"file_path":"'$project_dir'/manual.md"},"cwd":"'$project_dir'"}'
source "$repo_root/lib/session-state.sh"
state_set_alias "$project_dir" "session-manual" "manual-session" manual
rm -f "$CLAUDE_HARK_NAMER_CALLED"
printf '%s' "$manual_payload" | bash "$repo_root/hooks/claude-hark.sh" pre-tool-use >/dev/null
[[ ! -f "$CLAUDE_HARK_NAMER_CALLED" ]] || fail 'manual alias should not trigger session namer'
assert_eq 'manual-session' "$(jq -r '.sessions["session-manual"].alias.value' "$project_dir/.claude-hark/state.json")"

unset CLAUDE_HARK_SUMMARIZER_COMMAND CLAUDE_HARK_SESSION_NAMER_COMMAND
project_alias="$(basename "$project_dir")"
permission_write_payload='{"session_id":"session-write-1234","tool_name":"Write","tool_input":{"file_path":"'$project_dir'/config.json"},"cwd":"'$project_dir'"}'
permission_write_output="$(printf '%s' "$permission_write_payload" | bash "$repo_root/hooks/claude-hark.sh" permission)"
[[ -s "$CLAUDE_HARK_NOTIFY_STUB" ]] || fail 'write notification not written'
assert_eq "{\"systemMessage\":\"[$project_alias] 等待权限：Write；目的：需要回到 Claude Code 会话判断是否授权\"}" "$permission_write_output"
assert_eq 'fallback' "$(jq -r '.sessions["session-write-1234"].latestAction.source' "$project_dir/.claude-hark/state.json")"

export CLAUDE_HARK_SUMMARIZER_COMMAND="$stub"
notification_permission_payload='{"session_id":"session-notification-1234","notification_type":"permission_prompt","tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"'$project_dir'","message":"Claude needs permission to run Bash"}'
notify_size_before="$(wc -c < "$CLAUDE_HARK_NOTIFY_STUB" 2>/dev/null || printf 0)"
notification_permission_output="$(printf '%s' "$notification_permission_payload" | bash "$repo_root/hooks/claude-hark.sh" notification)"
notify_size_after="$(wc -c < "$CLAUDE_HARK_NOTIFY_STUB" 2>/dev/null || printf 0)"
assert_eq '' "$notification_permission_output"
assert_eq "$notify_size_before" "$notify_size_after"
assert_eq 'notification' "$(jq -r '.sessions["session-notification-1234"].latestAction.event' "$project_dir/.claude-hark/state.json")"
assert_eq 'active' "$(jq -r '.sessions["session-notification-1234"].latestAction.status' "$project_dir/.claude-hark/state.json")"
assert_eq 'llm' "$(jq -r '.sessions["session-notification-1234"].latestAction.source' "$project_dir/.claude-hark/state.json")"

idle_notification_payload='{"session_id":"session-idle-notification","notification_type":"idle_prompt","cwd":"'$project_dir'","message":"Claude is idle"}'
idle_notification_output="$(printf '%s' "$idle_notification_payload" | bash "$repo_root/hooks/claude-hark.sh" notification)"
assert_eq '' "$idle_notification_output"

elicitation_payload='{"session_id":"session-elicitation","cwd":"'$project_dir'"}'
elicitation_output="$(printf '%s' "$elicitation_payload" | bash "$repo_root/hooks/claude-hark.sh" elicitation)"
[[ -s "$CLAUDE_HARK_NOTIFY_STUB" ]] || fail 'elicitation notification not written'
assert_eq "{\"systemMessage\":\"[$project_alias] 等待你的选择；目的：请选择下一步通知样式\"}" "$elicitation_output"
assert_eq 'elicitation' "$(jq -r '.sessions["session-elicitation"].latestAction.display.kind' "$project_dir/.claude-hark/state.json")"
assert_contains "$(jq -r '.sessions["session-elicitation"].hookEvents[0].purpose' "$project_dir/.claude-hark/state.json")" '<event>elicitation</event>'

elicitation_message_payload='{"session_id":"session-elicitation-message","cwd":"'$project_dir'","message":"请选择下一步通知样式"}'
elicitation_message_output="$(printf '%s' "$elicitation_message_payload" | bash "$repo_root/hooks/claude-hark.sh" elicitation)"
[[ -s "$CLAUDE_HARK_NOTIFY_STUB" ]] || fail 'message elicitation notification not written'
assert_eq "{\"systemMessage\":\"[$project_alias] 等待你的选择；目的：请选择下一步通知样式\"}" "$elicitation_message_output"

edit_diff_payload='{"session_id":"session-edit-diff","tool_name":"Edit","tool_input":{"file_path":"'$project_dir'/hooks/claude-hark.sh","old_string":"# Notify when Claude is waiting for an explicit user choice.","new_string":"# 用户输入请求没有工具上下文，直接用 payload message 生成摘要。"},"cwd":"'$project_dir'"}'
edit_diff_output="$(printf '%s' "$edit_diff_payload" | bash "$repo_root/hooks/claude-hark.sh" permission)"
[[ -s "$CLAUDE_HARK_NOTIFY_STUB" ]] || fail 'edit diff notification not written'
assert_contains "$edit_diff_output" 'systemMessage'

user_prompt_payload='{"session_id":"session-lifecycle","cwd":"'$project_dir'","prompt":"请检查当前测试状态"}'
printf '%s' "$user_prompt_payload" | bash "$repo_root/hooks/claude-hark.sh" user-prompt-submit >/dev/null
assert_eq 'user-prompt-submit' "$(jq -r '.sessions["session-lifecycle"].latestAction.event' "$project_dir/.claude-hark/state.json")"
assert_eq 'active' "$(jq -r '.sessions["session-lifecycle"].latestAction.status' "$project_dir/.claude-hark/state.json")"

post_tool_payload='{"session_id":"session-lifecycle","tool_name":"Read","tool_input":{"file_path":"'$project_dir'/README.md"},"cwd":"'$project_dir'"}'
printf '%s' "$post_tool_payload" | bash "$repo_root/hooks/claude-hark.sh" post-tool-use >/dev/null
assert_eq 'post-tool-use' "$(jq -r '.sessions["session-lifecycle"].latestAction.event' "$project_dir/.claude-hark/state.json")"
assert_eq 'active' "$(jq -r '.sessions["session-lifecycle"].latestAction.status' "$project_dir/.claude-hark/state.json")"

post_tool_failure_payload='{"session_id":"session-lifecycle","tool_name":"Bash","tool_input":{"command":"npm test","description":"Run tests"},"cwd":"'$project_dir'"}'
printf '%s' "$post_tool_failure_payload" | bash "$repo_root/hooks/claude-hark.sh" post-tool-use-failure >/dev/null
assert_eq 'post-tool-use-failure' "$(jq -r '.sessions["session-lifecycle"].latestAction.event' "$project_dir/.claude-hark/state.json")"
assert_eq 'active' "$(jq -r '.sessions["session-lifecycle"].latestAction.status' "$project_dir/.claude-hark/state.json")"

stop_payload='{"session_id":"session-lifecycle","cwd":"'$project_dir'"}'
printf '%s' "$stop_payload" | bash "$repo_root/hooks/claude-hark.sh" stop >/dev/null
assert_eq 'stop' "$(jq -r '.sessions["session-lifecycle"].latestAction.event' "$project_dir/.claude-hark/state.json")"
assert_eq 'waiting_for_user' "$(jq -r '.sessions["session-lifecycle"].latestAction.status' "$project_dir/.claude-hark/state.json")"
assert_eq 'waiting_for_user' "$(jq -r '.sessions["session-lifecycle"].hookEvents[-1].status' "$project_dir/.claude-hark/state.json")"

stop_failure_payload='{"session_id":"session-failure","cwd":"'$project_dir'"}'
printf '%s' "$stop_failure_payload" | bash "$repo_root/hooks/claude-hark.sh" stop-failure >/dev/null
assert_eq 'stop-failure' "$(jq -r '.sessions["session-failure"].latestAction.event' "$project_dir/.claude-hark/state.json")"
assert_eq 'failed' "$(jq -r '.sessions["session-failure"].latestAction.status' "$project_dir/.claude-hark/state.json")"
