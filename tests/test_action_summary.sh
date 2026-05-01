#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/action-summary.sh"

tmp_dir="$(mktemp -d)"

payload='{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/tmp/app/README.md"}}'
assert_eq 'Edit' "$(extract_tool_name "$payload")"
assert_eq '{"file_path":"/tmp/app/README.md"}' "$(extract_tool_input_json "$payload")"

assert_eq 'README.md' "$(action_target_from_tool_input 'Edit' '{"file_path":"/tmp/app/README.md"}')"
assert_eq 'config.json' "$(action_target_from_tool_input 'Write' '{"file_path":"/tmp/app/config.json"}')"
assert_eq 'npm test' "$(action_target_from_tool_input 'Bash' '{"command":"npm test"}')"

assert_eq '准备修改 README.md 以完成当前步骤' "$(fallback_action_summary 'permission' 'Edit' '{"file_path":"/tmp/app/README.md"}')"
assert_eq '准备写入 config.json 以完成当前步骤' "$(fallback_action_summary 'permission' 'Write' '{"file_path":"/tmp/app/config.json"}')"
assert_eq '运行验证命令确认当前结果' "$(fallback_action_summary 'permission' 'Bash' '{"command":"npm test"}')"
assert_eq '等待你做选择以继续当前任务' "$(fallback_action_summary 'elicitation' 'unknown' '{}')"

stub="$tmp_dir/summarizer.sh"
cat > "$stub" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
input="$(cat)"
printf '%s' "$input" > "$CLAUDE_HARK_STUB_INPUT"
printf ' - 准备调整 README 的项目定位说明\n第二行应被忽略\n'
SH
chmod +x "$stub"
export CLAUDE_HARK_STUB_INPUT="$tmp_dir/input.json"
export CLAUDE_HARK_SUMMARIZER_COMMAND="$stub"

summary="$(summarize_action 'pre-tool-use' 'Edit' '{"file_path":"/tmp/app/README.md","old_string":"api_key=abc123","new_string":"password=secret-value"}')"
assert_eq '准备调整 README 的项目定位说明' "$summary"
assert_contains "$(cat "$CLAUDE_HARK_STUB_INPUT")" 'README.md'
assert_contains "$(cat "$CLAUDE_HARK_STUB_INPUT")" '[REDACTED]'

failing_stub="$tmp_dir/failing.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$failing_stub"
chmod +x "$failing_stub"
export CLAUDE_HARK_SUMMARIZER_COMMAND="$failing_stub"
assert_eq '准备修改 README.md 以完成当前步骤' "$(summarize_action 'pre-tool-use' 'Edit' '{"file_path":"/tmp/app/README.md"}')"

export CLAUDE_HARK_SUMMARIZER_COMMAND="$stub"
export CLAUDE_HARK_SUMMARIZING=1
rm -f "$CLAUDE_HARK_STUB_INPUT"
assert_eq '准备修改 README.md 以完成当前步骤' "$(summarize_action 'pre-tool-use' 'Edit' '{"file_path":"/tmp/app/README.md"}')"
[[ ! -f "$CLAUDE_HARK_STUB_INPUT" ]] || fail 'summarizer guard should prevent external call'
unset CLAUDE_HARK_SUMMARIZING

long_stub="$tmp_dir/long.sh"
cat > "$long_stub" <<'SH'
#!/usr/bin/env bash
printf '这是一段非常长的摘要，应该被截断以避免通知内容过长导致用户无法快速理解当前权限申请或文件修改的目的，同时也避免在通知中心展示过多敏感信息'
SH
chmod +x "$long_stub"
export CLAUDE_HARK_SUMMARIZER_COMMAND="$long_stub"
long_summary="$(summarize_action 'permission' 'Bash' '{"command":"npm run build"}')"
[[ ${#long_summary} -le 80 ]] || fail 'summary should be length limited'
