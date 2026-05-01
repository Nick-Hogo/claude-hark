#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

project_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$project_dir/notify.log"

stub="$project_dir/summarizer.sh"
cat > "$stub" <<'SH'
#!/usr/bin/env bash
cat >/dev/null
printf '准备调整 README 的项目定位说明\n'
SH
chmod +x "$stub"
export CLAUDE_HARK_SUMMARIZER_COMMAND="$stub"

pre_tool_payload='{"session_id":"session-edit-1234","tool_name":"Edit","tool_input":{"file_path":"'$project_dir'/README.md","old_string":"old","new_string":"new"},"cwd":"'$project_dir'"}'
pre_tool_output="$(printf '%s' "$pre_tool_payload" | bash "$repo_root/hooks/claude-hark.sh" pre-tool-use)"
assert_eq '' "$pre_tool_output"
assert_eq '准备调整 README 的项目定位说明' "$(jq -r '.sessions["session-edit-1234"].latestAction.summary' "$project_dir/.claude-hark/state.json")"
assert_eq 'README.md' "$(jq -r '.sessions["session-edit-1234"].latestAction.target' "$project_dir/.claude-hark/state.json")"

permission_edit_payload='{"session_id":"session-edit-1234","tool_name":"Edit","tool_input":{"file_path":"'$project_dir'/README.md"},"cwd":"'$project_dir'"}'
permission_edit_output="$(printf '%s' "$permission_edit_payload" | bash "$repo_root/hooks/claude-hark.sh" permission)"
project_alias="$(basename "$project_dir")"
assert_eq "Claude Code|[$project_alias] 等待权限：Edit；目的：准备调整 README 的项目定位说明" "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
assert_eq "{\"systemMessage\":\"[$project_alias] 等待权限：Edit；目的：准备调整 README 的项目定位说明\"}" "$permission_edit_output"

unset CLAUDE_HARK_SUMMARIZER_COMMAND
permission_write_payload='{"session_id":"session-write-1234","tool_name":"Write","tool_input":{"file_path":"'$project_dir'/config.json"},"cwd":"'$project_dir'"}'
permission_write_output="$(printf '%s' "$permission_write_payload" | bash "$repo_root/hooks/claude-hark.sh" permission)"
assert_eq "Claude Code|[$project_alias] 等待权限：Write；目的：准备写入 config.json 以完成当前步骤" "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
assert_eq "{\"systemMessage\":\"[$project_alias] 等待权限：Write；目的：准备写入 config.json 以完成当前步骤\"}" "$permission_write_output"

elicitation_payload='{"session_id":"session-elicitation","cwd":"'$project_dir'"}'
elicitation_output="$(printf '%s' "$elicitation_payload" | bash "$repo_root/hooks/claude-hark.sh" elicitation)"
assert_eq "Claude Code|[$project_alias] 等待你的选择；目的：等待你做选择以继续当前任务" "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
assert_eq "{\"systemMessage\":\"[$project_alias] 等待你的选择；目的：等待你做选择以继续当前任务\"}" "$elicitation_output"
