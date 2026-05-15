#!/usr/bin/env bash
set -euo pipefail

# ---- 模块加载 ----
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/lib/common.sh"
source "$repo_root/lib/session-state.sh"
source "$repo_root/lib/notifier.sh"
action_summary_py="$repo_root/lib/action_summary.py"

action_summary() {
  python3 "$action_summary_py" "$@"
}

# ---- 解析 Claude Code hook payload ----
event_kind="${1:-}"
payload="$(cat)"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // ""')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // .tool_input.cwd // "."')"
branch_name="$(printf '%s' "$payload" | jq -r '.git_branch // ""')"
tool_name="$(action_summary extract-tool-name "$payload")"
tool_input_json="$(action_summary extract-tool-input-json "$payload")"
alias_value="$(state_resolve_alias "$cwd" "$session_id" "$branch_name")"
now_value="${CLAUDE_HARK_NOW:-$(date '+%H:%M:%S')}"

record_handler_event() {
  local normalized_event="$1"
  local history_json result_json result_event result_tool result_target result_summary result_source result_status display_json purpose notification_title notification_body system_message
  history_json="$(state_get_hook_history "$cwd" "$session_id")"
  result_json="$(action_summary handle-event "$normalized_event" "$payload" "$history_json")"
  result_event="$(printf '%s' "$result_json" | jq -r '.event')"
  result_tool="$(printf '%s' "$result_json" | jq -r '.toolName')"
  result_target="$(printf '%s' "$result_json" | jq -r '.target')"
  result_summary="$(printf '%s' "$result_json" | jq -r '.summary')"
  result_source="$(printf '%s' "$result_json" | jq -r '.source')"
  result_status="$(printf '%s' "$result_json" | jq -r '.status')"
  purpose="$(printf '%s' "$result_json" | jq -r '.purpose')"
  display_json="$(printf '%s' "$result_json" | jq -c '.display')"
  state_set_latest_action "$cwd" "$session_id" "$result_event" "$result_tool" "$result_target" "$result_summary" "$result_source" "$display_json" "$result_status"
  state_append_hook_event "$cwd" "$session_id" "$result_event" "$result_tool" "$result_target" "$result_summary" "$result_source" "$purpose" "$result_status" "$display_json"

  notification_body="$(printf '%s' "$result_json" | jq -r '.notificationBody // ""')"
  if [[ -n "$notification_body" ]]; then
    notification_title="$(printf '%s' "$result_json" | jq -r '.notificationTitle // ""')"
    notify_user "${notification_title:-${alias_value} · ${now_value}}" "$notification_body"
  fi

  system_message="$(printf '%s' "$result_json" | jq -r '.systemMessage // ""')"
  if [[ -n "$system_message" ]]; then
    printf '{"systemMessage":%s}\n' "$(json_escape "[${alias_value}] ${system_message}")"
  fi
}

# ---- 分发 hook 事件 ----
case "$event_kind" in
  user-prompt-submit)
    record_handler_event "user-prompt-submit"
    ;;
  pre-tool-use)
    record_handler_event "pre-tool-use"
    if state_should_generate_ai_alias "$cwd" "$session_id" && [[ -n "${CLAUDE_HARK_SESSION_NAMER_COMMAND:-}" ]]; then
      session_metadata="$(action_summary generate-session-metadata "$cwd" "$branch_name" "pre-tool-use" "$tool_name" "$tool_input_json")"
      session_name="$(printf '%s' "$session_metadata" | jq -r '.name // ""')"
      session_description="$(printf '%s' "$session_metadata" | jq -r '.description // ""')"
      [[ -n "$session_name" ]] && state_set_alias "$cwd" "$session_id" "$session_name" ai
      [[ -n "$session_description" ]] && state_set_description "$cwd" "$session_id" "$session_description" ai
    fi
    ;;
  post-tool-use)
    record_handler_event "post-tool-use"
    ;;
  post-tool-use-failure)
    record_handler_event "post-tool-use-failure"
    ;;
  stop)
    record_handler_event "stop"
    ;;
  stop-failure)
    record_handler_event "stop-failure"
    ;;
  permission)
    record_handler_event "permission"
    ;;
  notification)
    notification_type="$(printf '%s' "$payload" | jq -r '.notification_type // ""')"
    if [[ "$notification_type" == "permission_prompt" ]]; then
      record_handler_event "permission"
    fi
    ;;
  elicitation)
    record_handler_event "elicitation"
    ;;
  *)
    echo "unsupported event kind" >&2
    exit 1
    ;;
esac
