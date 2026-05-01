#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/lib/common.sh"
source "$repo_root/lib/session-state.sh"
source "$repo_root/lib/action-summary.sh"
source "$repo_root/lib/notifier.sh"

event_kind="${1:-}"
payload="$(cat)"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // ""')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // .tool_input.cwd // "."')"
branch_name="$(printf '%s' "$payload" | jq -r '.git_branch // ""')"
tool_name="$(extract_tool_name "$payload")"
tool_input_json="$(extract_tool_input_json "$payload")"
alias_value="$(state_resolve_alias "$cwd" "$session_id" "$branch_name")"

case "$event_kind" in
  pre-tool-use)
    summary="$(summarize_action "pre-tool-use" "$tool_name" "$tool_input_json")"
    target="$(action_target_from_tool_input "$tool_name" "$tool_input_json")"
    source_value="$(action_summary_source)"
    state_set_latest_action "$cwd" "$session_id" "pre-tool-use" "$tool_name" "$target" "$summary" "$source_value"
    ;;
  permission)
    summary="$(state_get_recent_action_summary "$cwd" "$session_id" "${CLAUDE_HARK_INTENT_TTL_SECONDS:-120}")"
    if [[ -z "$summary" ]]; then
      summary="$(summarize_action "permission" "$tool_name" "$tool_input_json")"
    fi
    target="$(action_target_from_tool_input "$tool_name" "$tool_input_json")"
    source_value="$(action_summary_source)"
    state_set_latest_action "$cwd" "$session_id" "permission" "$tool_name" "$target" "$summary" "$source_value"
    message="[${alias_value}] 等待权限：${tool_name}；目的：${summary}"
    notify_user 'Claude Code' "$message"
    printf '{"systemMessage":%s}\n' "$(json_escape "$message")"
    ;;
  elicitation)
    summary="$(fallback_action_summary "elicitation" "$tool_name" "$tool_input_json")"
    state_set_latest_action "$cwd" "$session_id" "elicitation" "$tool_name" "$tool_name" "$summary" "fallback"
    message="[${alias_value}] 等待你的选择；目的：${summary}"
    notify_user 'Claude Code' "$message"
    printf '{"systemMessage":%s}\n' "$(json_escape "$message")"
    ;;
  *)
    echo "unsupported event kind" >&2
    exit 1
    ;;
esac
