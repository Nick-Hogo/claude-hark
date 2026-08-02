#!/usr/bin/env bash
set -euo pipefail
# 验证内置摘要客户端对 OpenAI-compatible 与 Anthropic Messages API 的适配。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

tmp_dir="$(mktemp -d)"
fake_bin="$tmp_dir/bin"
mkdir -p "$fake_bin"

cat > "$fake_bin/curl" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$CLAUDE_HARK_CURL_ARGS"
request_file=''
for arg in "$@"; do
  case "$arg" in @*) request_file="${arg#@}" ;; esac
done
[[ -n "$request_file" ]] || exit 2
cp "$request_file" "$CLAUDE_HARK_CURL_BODY"
case "$CLAUDE_HARK_LLM_PROVIDER" in
  openai) printf '%s\n' '{"output":[{"type":"message","content":[{"type":"output_text","text":"{\"summary\":\"OpenAI Responses 正常\"}"}]}]}' ;;
  openai-compat) printf '%s\n' '{"choices":[{"message":{"content":"{\"summary\":\"OpenAI Compatible 正常\"}"}}]}' ;;
  anthropic) printf '%s\n' '{"content":[{"type":"text","text":"{\"summary\":\"Anthropic 正常\"}"}]}' ;;
esac
SH
chmod +x "$fake_bin/curl"

client="$repo_root/bin/claude-hark-summarize"
# Unit tests inject provider settings directly; point runtime settings at a missing file.
common_env=(
  "CLAUDE_HARK_APP_SETTINGS_PATH=$tmp_dir/no-settings.json"
  "PATH=$fake_bin:$PATH"
  "CLAUDE_HARK_LLM_MODEL=test-model"
  "CLAUDE_HARK_LLM_API_KEY=test-key"
  "CLAUDE_HARK_SUMMARIZER_TIMEOUT=3"
  "CLAUDE_HARK_CURL_ARGS=$tmp_dir/curl.args"
  "CLAUDE_HARK_CURL_BODY=$tmp_dir/curl.body"
)

openai_output="$(printf '分析 OpenAI Responses' | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=openai CLAUDE_HARK_LLM_URL= "$client")"
assert_eq '{"summary":"OpenAI Responses 正常"}' "$openai_output"
openai_args="$(cat "$tmp_dir/curl.args")"
assert_contains "$openai_args" 'Authorization: Bearer test-key'
assert_contains "$openai_args" 'https://api.openai.com/v1/responses'
assert_eq '分析 OpenAI Responses' "$(jq -r '.input' "$tmp_dir/curl.body")"

printf '分析 OpenAI 网关' | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=openai CLAUDE_HARK_LLM_URL=https://gateway.example/api "$client" >/dev/null
assert_contains "$(cat "$tmp_dir/curl.args")" 'https://gateway.example/api/v1/responses'
printf '分析完整 OpenAI 地址' | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=openai CLAUDE_HARK_LLM_URL=https://gateway.example/api/v1/responses/ "$client" >/dev/null
assert_contains "$(cat "$tmp_dir/curl.args")" 'https://gateway.example/api/v1/responses'
assert_not_contains "$(cat "$tmp_dir/curl.args")" 'v1/responses/v1/responses'

compat_output="$(printf '分析兼容接口' | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=openai-compat CLAUDE_HARK_LLM_URL= "$client")"
assert_eq '{"summary":"OpenAI Compatible 正常"}' "$compat_output"
compat_args="$(cat "$tmp_dir/curl.args")"
assert_contains "$compat_args" 'https://api.openai.com/v1/chat/completions'
assert_eq '分析兼容接口' "$(jq -r '.messages[0].content' "$tmp_dir/curl.body")"
printf '分析兼容网关' | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=openai-compat CLAUDE_HARK_LLM_URL=https://gateway.example/api "$client" >/dev/null
assert_contains "$(cat "$tmp_dir/curl.args")" 'https://gateway.example/api/v1/chat/completions'

anthropic_output="$(printf '分析 Anthropic 事件' | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=anthropic CLAUDE_HARK_LLM_URL= "$client")"
assert_eq '{"summary":"Anthropic 正常"}' "$anthropic_output"
anthropic_args="$(cat "$tmp_dir/curl.args")"
assert_contains "$anthropic_args" 'x-api-key: test-key'
assert_contains "$anthropic_args" 'anthropic-version: 2023-06-01'
assert_contains "$anthropic_args" 'https://api.anthropic.com/v1/messages'

printf '分析 Anthropic 网关' | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=anthropic CLAUDE_HARK_LLM_URL=https://gateway.example/api-proxy "$client" >/dev/null
assert_contains "$(cat "$tmp_dir/curl.args")" 'https://gateway.example/api-proxy/v1/messages'
printf '分析完整 Anthropic 地址' | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=anthropic CLAUDE_HARK_LLM_URL=https://gateway.example/api-proxy/v1/messages/ "$client" >/dev/null
assert_contains "$(cat "$tmp_dir/curl.args")" 'https://gateway.example/api-proxy/v1/messages'
assert_not_contains "$(cat "$tmp_dir/curl.args")" 'v1/messages/v1/messages'
assert_not_contains "$anthropic_args" 'Authorization: Bearer'
assert_eq 'test-model' "$(jq -r '.model' "$tmp_dir/curl.body")"
assert_eq '600' "$(jq -r '.max_tokens' "$tmp_dir/curl.body")"
assert_eq '分析完整 Anthropic 地址' "$(jq -r '.messages[0].content' "$tmp_dir/curl.body")"

if printf test | env "${common_env[@]}" CLAUDE_HARK_LLM_PROVIDER=unknown CLAUDE_HARK_LLM_URL= "$client" >"$tmp_dir/unknown.out" 2>"$tmp_dir/unknown.err"; then
  fail 'unknown provider should fail'
fi
assert_contains "$(cat "$tmp_dir/unknown.err")" 'Unsupported CLAUDE_HARK_LLM_PROVIDER: unknown'
