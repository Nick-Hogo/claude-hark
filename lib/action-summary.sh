#!/usr/bin/env bash
set -euo pipefail

summary_max_chars() {
  printf '%s\n' "${CLAUDE_HARK_SUMMARY_MAX_CHARS:-80}"
}

extract_tool_name() {
  local payload="$1"
  printf '%s' "$payload" | jq -r '.tool_name // "unknown"'
}

extract_tool_input_json() {
  local payload="$1"
  printf '%s' "$payload" | jq -c '.tool_input // {}'
}

json_string_field() {
  local json="$1"
  local field="$2"
  printf '%s' "$json" | jq -r --arg field "$field" '.[$field] // ""'
}

truncate_text() {
  local text="$1"
  local max_chars="${2:-500}"
  python3 -c 'import sys; text=sys.stdin.read(); max_chars=int(sys.argv[1]); print(text[:max_chars], end="")' "$max_chars" <<< "$text"
}

action_target_from_tool_input() {
  local tool_name="$1"
  local tool_input_json="$2"
  local file_path command_text

  case "$tool_name" in
    Edit|Write)
      file_path="$(json_string_field "$tool_input_json" file_path)"
      [[ -n "$file_path" ]] && basename "$file_path" && return
      ;;
    Bash)
      command_text="$(json_string_field "$tool_input_json" command)"
      if [[ -n "$command_text" ]]; then
        truncate_text "$command_text" 80
        printf '\n'
        return
      fi
      ;;
  esac

  printf '%s\n' "$tool_name"
}

fallback_action_summary() {
  local event_kind="$1"
  local tool_name="$2"
  local tool_input_json="$3"
  local file_path file_name command_text

  if [[ "$event_kind" == "elicitation" ]]; then
    printf '等待你做选择以继续当前任务\n'
    return
  fi

  case "$tool_name" in
    Edit)
      file_path="$(json_string_field "$tool_input_json" file_path)"
      if [[ -n "$file_path" ]]; then
        file_name="$(basename "$file_path")"
        printf '准备修改 %s 以完成当前步骤\n' "$file_name"
        return
      fi
      ;;
    Write)
      file_path="$(json_string_field "$tool_input_json" file_path)"
      if [[ -n "$file_path" ]]; then
        file_name="$(basename "$file_path")"
        printf '准备写入 %s 以完成当前步骤\n' "$file_name"
        return
      fi
      ;;
    Bash)
      command_text="$(json_string_field "$tool_input_json" command)"
      if [[ "$command_text" == *test* || "$command_text" == *vitest* || "$command_text" == *jest* || "$command_text" == *pytest* ]]; then
        printf '运行验证命令确认当前结果\n'
        return
      fi
      if [[ "$command_text" == *build* || "$command_text" == *tsc* || "$command_text" == *compile* ]]; then
        printf '运行构建检查当前结果\n'
        return
      fi
      if [[ "$command_text" == git\ status* || "$command_text" == git\ diff* || "$command_text" == git\ log* || "$command_text" == git\ show* ]]; then
        printf '检查当前仓库状态\n'
        return
      fi
      printf '执行当前步骤需要的命令\n'
      return
      ;;
    Read)
      printf '读取上下文继续分析\n'
      return
      ;;
    Glob|Grep)
      printf '搜索相关代码位置\n'
      return
      ;;
    WebSearch|WebFetch)
      printf '获取外部资料继续任务\n'
      return
      ;;
  esac

  printf '继续当前任务\n'
}

redact_sensitive_text() {
  local text="$1"
  printf '%s' "$text" | python3 -c '
import re, sys
text = sys.stdin.read()
patterns = [
    r"(?i)(api[_-]?key\s*[=:]\s*)[^\s,;]+",
    r"(?i)(token\s*[=:]\s*)[^\s,;]+",
    r"(?i)(password\s*[=:]\s*)[^\s,;]+",
    r"(?i)(secret\s*[=:]\s*)[^\s,;]+",
]
for pattern in patterns:
    text = re.sub(pattern, lambda m: m.group(1) + "[REDACTED]", text)
print(text, end="")
'
}

sanitize_action_payload() {
  local event_kind="$1"
  local tool_name="$2"
  local tool_input_json="$3"
  local sanitized

  case "$tool_name" in
    Edit)
      sanitized="$(printf '%s' "$tool_input_json" | jq '{file_path: (.file_path // ""), old_string: (.old_string // ""), new_string: (.new_string // "")}')"
      ;;
    Write)
      sanitized="$(printf '%s' "$tool_input_json" | jq '{file_path: (.file_path // ""), content: (.content // "")}')"
      ;;
    Bash)
      sanitized="$(printf '%s' "$tool_input_json" | jq '{command: (.command // "")}')"
      ;;
    *)
      sanitized="$(printf '%s' "$tool_input_json" | jq '{tool_input: .}')"
      ;;
  esac

  sanitized="$(truncate_text "$sanitized" 1200)"
  redact_sensitive_text "$sanitized"
}

normalize_action_summary() {
  local raw="$1"
  local max_chars
  max_chars="$(summary_max_chars)"
  printf '%s' "$raw" | python3 -c '
import re, sys
max_chars = int(sys.argv[1])
lines = [line.strip() for line in sys.stdin.read().splitlines()]
line = next((line for line in lines if line), "")
line = re.sub(r"^[\-*>#\d\.、\s]+", "", line)
line = line.strip(" `\t\r\n")
if len(line) > max_chars:
    line = line[:max_chars]
print(line, end="")
' "$max_chars"
}

run_external_summarizer() {
  local sanitized_payload="$1"
  local timeout_seconds="${CLAUDE_HARK_SUMMARIZER_TIMEOUT:-3}"

  python3 -c '
import os, subprocess, sys
command = os.environ["CLAUDE_HARK_SUMMARIZER_COMMAND"]
timeout = float(os.environ.get("CLAUDE_HARK_SUMMARIZER_TIMEOUT", sys.argv[1]))
payload = sys.stdin.read()
env = os.environ.copy()
env["CLAUDE_HARK_SUMMARIZING"] = "1"
try:
    result = subprocess.run(command, input=payload, text=True, shell=True, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=timeout, env=env)
except Exception:
    sys.exit(1)
if result.returncode != 0:
    sys.exit(result.returncode)
print(result.stdout, end="")
' "$timeout_seconds" <<< "$sanitized_payload"
}

action_summary_source() {
  if [[ -n "${CLAUDE_HARK_SUMMARIZER_COMMAND:-}" && "${CLAUDE_HARK_SUMMARIZING:-}" != "1" ]]; then
    printf 'external\n'
  else
    printf 'fallback\n'
  fi
}

summarize_action() {
  local event_kind="$1"
  local tool_name="$2"
  local tool_input_json="$3"
  local fallback sanitized raw normalized

  fallback="$(fallback_action_summary "$event_kind" "$tool_name" "$tool_input_json")"

  if [[ -z "${CLAUDE_HARK_SUMMARIZER_COMMAND:-}" || "${CLAUDE_HARK_SUMMARIZING:-}" == "1" ]]; then
    printf '%s\n' "$fallback"
    return
  fi

  sanitized="$(sanitize_action_payload "$event_kind" "$tool_name" "$tool_input_json")"
  if raw="$(run_external_summarizer "$sanitized")"; then
    normalized="$(normalize_action_summary "$raw")"
    if [[ -n "$normalized" ]]; then
      printf '%s\n' "$normalized"
      return
    fi
  fi

  printf '%s\n' "$fallback"
}
