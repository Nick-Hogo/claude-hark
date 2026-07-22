#!/usr/bin/env bash
set -euo pipefail
# 这个测试脚本验证 hook 摘要、处理器和通知正文生成行为。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

py_file="$repo_root/lib/action_summary.py"
tmp_dir="$(mktemp -d)"

# 调用 Python 摘要脚本并把参数原样转发给对应命令。
action_summary() {
  python3 "$py_file" "$@"
}

payload='{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/tmp/app/README.md"}}'
assert_eq 'Edit' "$(action_summary extract-tool-name "$payload")"
assert_eq '{"file_path":"/tmp/app/README.md"}' "$(action_summary extract-tool-input-json "$payload")"

assert_eq 'README.md' "$(action_summary action-target 'Edit' '{"file_path":"/tmp/app/README.md"}')"
assert_eq 'npm test' "$(action_summary action-target 'Bash' '{"command":"npm test"}')"
context_json="$(action_summary extract-hook-context 'permission' 'Bash' '{"command":"npm test"}')"
assert_contains "$context_json" '"command_preview": "npm test"'
assert_not_contains "$context_json" 'command_category'

handler_stub="$tmp_dir/handler-summarizer.sh"
cat > "$handler_stub" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat > "$CLAUDE_HARK_HANDLER_STUB_INPUT"
cat <<'OUT'
标题：LLM权限分析
摘要：运行完整测试套件验证安装改动
目的：测试验证
细节：执行 bash tests/run.sh
建议：确认是本地测试命令
审阅点：检查命令范围
下一步：批准后查看测试结果
OUT
SH
chmod +x "$handler_stub"
export CLAUDE_HARK_HANDLER_STUB_INPUT="$tmp_dir/handler-input.txt"
export CLAUDE_HARK_SUMMARIZER_COMMAND="$handler_stub"
handler_json="$(action_summary handle-event permission '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"bash tests/run.sh","description":"Run full test suite"},"cwd":"/tmp/app"}' '[]')"
assert_eq '运行完整测试套件验证安装改动' "$(printf '%s' "$handler_json" | jq -r '.summary')"
assert_eq '测试验证' "$(printf '%s' "$handler_json" | jq -r '.display.purpose')"
assert_eq '批准后查看测试结果' "$(printf '%s' "$handler_json" | jq -r '.display.nextAction')"
assert_eq 'llm' "$(printf '%s' "$handler_json" | jq -r '.source')"
assert_eq 'generated' "$(printf '%s' "$handler_json" | jq -r '.llmStatus')"
assert_eq 'false' "$(printf '%s' "$handler_json" | jq -r '.usedFallback')"
assert_contains "$(cat "$CLAUDE_HARK_HANDLER_STUB_INPUT")" '<event>permission</event>'
assert_contains "$(cat "$CLAUDE_HARK_HANDLER_STUB_INPUT")" '<context>'
assert_contains "$(cat "$CLAUDE_HARK_HANDLER_STUB_INPUT")" 'bash tests/run.sh'
assert_contains "$(cat "$CLAUDE_HARK_HANDLER_STUB_INPUT")" '标题/摘要/目的/细节/建议/审阅点/下一步'
assert_eq '执行 bash tests/run.sh' "$(printf '%s' "$handler_json" | jq -r '.display.details[0]')"
assert_eq '检查命令范围' "$(printf '%s' "$handler_json" | jq -r '.display.review[0]')"

unset CLAUDE_HARK_SUMMARIZER_COMMAND CLAUDE_HARK_HANDLER_STUB_INPUT
fallback_handler_json="$(action_summary handle-event permission '{"session_id":"s1","tool_name":"Bash","tool_input":{"command":"bash tests/run.sh","description":"Run full test suite"},"cwd":"/tmp/app"}' '[]')"
assert_eq 'fallback' "$(printf '%s' "$fallback_handler_json" | jq -r '.source')"
assert_eq 'unavailable' "$(printf '%s' "$fallback_handler_json" | jq -r '.llmStatus')"
assert_eq 'true' "$(printf '%s' "$fallback_handler_json" | jq -r '.usedFallback')"
assert_eq '需要回到 Claude Code 会话判断是否授权' "$(printf '%s' "$fallback_handler_json" | jq -r '.summary')"
assert_eq '等待人工确认' "$(printf '%s' "$fallback_handler_json" | jq -r '.display.purpose')"
assert_not_contains "$(printf '%s' "$fallback_handler_json" | jq -r '.summary')" '运行完整测试套件'

redacting_stub="$tmp_dir/redacting-summarizer.sh"
cat > "$redacting_stub" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
cat > "$CLAUDE_HARK_STUB_INPUT"
printf '{"title":"密钥检查","summary":"处理 api_key=abc123 和 password=secret-value","purpose":"审阅敏感输入","details":["token=secret-value"],"suggestion":"确认脱敏结果","review":["api_key=abc123"],"nextAction":"检查 password=secret-value"}'
SH
chmod +x "$redacting_stub"
export CLAUDE_HARK_STUB_INPUT="$tmp_dir/redacting-input.txt"
export CLAUDE_HARK_SUMMARIZER_COMMAND="$redacting_stub"
redacted_json="$(action_summary handle-event pre-tool-use '{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/tmp/app/README.md","old_string":"api_key=abc123","new_string":"password=secret-value"},"cwd":"/tmp/app"}' '[]')"
assert_contains "$redacted_json" '[REDACTED]'
assert_not_contains "$redacted_json" 'abc123'
assert_not_contains "$redacted_json" 'secret-value'
assert_contains "$(cat "$CLAUDE_HARK_STUB_INPUT")" '"contains_redacted": true'
assert_not_contains "$(cat "$CLAUDE_HARK_STUB_INPUT")" 'abc123'

failing_stub="$tmp_dir/failing.sh"
printf '#!/usr/bin/env bash\nexit 1\n' > "$failing_stub"
chmod +x "$failing_stub"
export CLAUDE_HARK_SUMMARIZER_COMMAND="$failing_stub"
failing_json="$(action_summary handle-event pre-tool-use '{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/tmp/app/README.md"},"cwd":"/tmp/app"}' '[]')"
assert_eq 'fallback' "$(printf '%s' "$failing_json" | jq -r '.source')"
assert_eq 'failed' "$(printf '%s' "$failing_json" | jq -r '.llmStatus')"
assert_eq 'true' "$(printf '%s' "$failing_json" | jq -r '.usedFallback')"
assert_eq '需要查看 Claude Code 会话继续处理' "$(printf '%s' "$failing_json" | jq -r '.summary')"

export CLAUDE_HARK_SUMMARIZER_COMMAND="$redacting_stub"
export CLAUDE_HARK_SUMMARIZING=1
rm -f "$CLAUDE_HARK_STUB_INPUT"
guarded_json="$(action_summary handle-event pre-tool-use '{"session_id":"s1","tool_name":"Edit","tool_input":{"file_path":"/tmp/app/README.md"},"cwd":"/tmp/app"}' '[]')"
assert_eq 'fallback' "$(printf '%s' "$guarded_json" | jq -r '.source')"
assert_eq 'unavailable' "$(printf '%s' "$guarded_json" | jq -r '.llmStatus')"
assert_eq 'true' "$(printf '%s' "$guarded_json" | jq -r '.usedFallback')"
[[ ! -f "$CLAUDE_HARK_STUB_INPUT" ]] || fail 'summarizer guard should prevent external call'
unset CLAUDE_HARK_SUMMARIZING CLAUDE_HARK_SUMMARIZER_COMMAND CLAUDE_HARK_STUB_INPUT

unset CLAUDE_HARK_SESSION_NAMER_COMMAND CLAUDE_HARK_SESSION_NAMING
assert_eq 'disabled' "$(action_summary session-namer-available)"
namer_stub="$tmp_dir/namer.sh"
cat > "$namer_stub" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
input="$(cat)"
printf '%s' "$input" > "$CLAUDE_HARK_NAMER_STUB_INPUT"
printf '{"name":"  session-api-key=abc123  ","description":"Working with password=secret-value on README updates."}\n'
SH
chmod +x "$namer_stub"
export CLAUDE_HARK_SESSION_NAMER_COMMAND="$namer_stub"
export CLAUDE_HARK_NAMER_STUB_INPUT="$tmp_dir/namer-input.txt"
assert_eq 'configured' "$(action_summary session-namer-available)"
metadata="$(action_summary generate-session-metadata '/tmp/app' 'feature-x' 'pre-tool-use' 'Edit' '{"file_path":"/tmp/app/README.md","old_string":"api_key=abc123","new_string":"new"}')"
assert_contains "$metadata" '[REDACTED]'
assert_not_contains "$metadata" 'abc123'
assert_not_contains "$metadata" 'secret-value'
assert_contains "$(cat "$CLAUDE_HARK_NAMER_STUB_INPUT")" '"repo_name": "app"'
assert_contains "$(cat "$CLAUDE_HARK_NAMER_STUB_INPUT")" '"contains_redacted": true'
assert_not_contains "$(cat "$CLAUDE_HARK_NAMER_STUB_INPUT")" 'abc123'
assert_not_contains "$(cat "$CLAUDE_HARK_NAMER_STUB_INPUT")" 'command_category'

export CLAUDE_HARK_SESSION_NAMING=1
rm -f "$CLAUDE_HARK_NAMER_STUB_INPUT"
assert_eq 'disabled' "$(action_summary session-namer-available)"
assert_eq '{}' "$(action_summary generate-session-metadata '/tmp/app' 'main' 'pre-tool-use' 'Edit' '{"file_path":"/tmp/app/README.md"}')"
[[ ! -f "$CLAUDE_HARK_NAMER_STUB_INPUT" ]] || fail 'session namer guard should prevent external call'
unset CLAUDE_HARK_SESSION_NAMING CLAUDE_HARK_SESSION_NAMER_COMMAND

bad_namer_stub="$tmp_dir/bad-namer.sh"
printf '#!/usr/bin/env bash\nprintf not-json\n' > "$bad_namer_stub"
chmod +x "$bad_namer_stub"
export CLAUDE_HARK_SESSION_NAMER_COMMAND="$bad_namer_stub"
assert_eq '{}' "$(action_summary generate-session-metadata '/tmp/app' 'main' 'pre-tool-use' 'Edit' '{"file_path":"/tmp/app/README.md"}')"
