#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

state_path() {
  local cwd="${1:-}"
  printf '%s/state.json\n' "$(hark_home_for_cwd "$cwd")"
}

state_init() {
  local cwd="${1:-}"
  local path
  path="$(state_path "$cwd")"
  ensure_dir "$(dirname "$path")"
  [[ -f "$path" ]] || printf '{}\n' > "$path"
}

state_set_alias() {
  local cwd="$1"
  local session_id="$2"
  local alias_value="$3"
  local source_value="$4"
  local path tmp
  state_init "$cwd"
  path="$(state_path "$cwd")"
  tmp="$(mktemp)"
  jq --arg sid "$session_id" --arg alias "$alias_value" --arg source "$source_value" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    .sessions = (.sessions // {})
    | .sessions[$sid].alias = {value: $alias, source: $source, updatedAt: $now}
  ' "$path" > "$tmp"
  mv "$tmp" "$path"
}

state_get_alias() {
  local cwd="$1"
  local session_id="$2"
  state_init "$cwd"
  jq -r --arg sid "$session_id" '.sessions[$sid].alias.value // ""' "$(state_path "$cwd")"
}

state_get_alias_source() {
  local cwd="$1"
  local session_id="$2"
  state_init "$cwd"
  jq -r --arg sid "$session_id" '.sessions[$sid].alias.source // ""' "$(state_path "$cwd")"
}

state_clear_alias() {
  local cwd="$1"
  local session_id="$2"
  local path tmp
  state_init "$cwd"
  path="$(state_path "$cwd")"
  tmp="$(mktemp)"
  jq --arg sid "$session_id" 'del(.sessions[$sid].alias)' "$path" > "$tmp"
  mv "$tmp" "$path"
}

short_session_id() {
  local session_id="$1"
  printf 'sess:%s\n' "${session_id:0:8}"
}

state_generate_auto_alias() {
  local cwd="$1"
  local branch_name="$2"
  local repo_name
  repo_name="$(basename "$cwd")"

  if [[ -n "$branch_name" && -n "$repo_name" && "$repo_name" != "/" && "$repo_name" != "." ]]; then
    printf '%s:%s\n' "$repo_name" "$branch_name"
    return
  fi

  if [[ -n "$repo_name" && "$repo_name" != "/" && "$repo_name" != "." ]]; then
    printf '%s\n' "$repo_name"
    return
  fi

  printf ''
}

state_resolve_alias() {
  local cwd="$1"
  local session_id="$2"
  local branch_name="$3"
  local existing existing_source auto_alias

  existing="$(state_get_alias "$cwd" "$session_id")"
  existing_source="$(state_get_alias_source "$cwd" "$session_id")"
  if [[ -n "$existing" ]]; then
    printf '%s\n' "$existing"
    return
  fi

  auto_alias="$(state_generate_auto_alias "$cwd" "$branch_name")"
  if [[ -n "$auto_alias" ]]; then
    state_set_alias "$cwd" "$session_id" "$auto_alias" "auto"
    printf '%s\n' "$auto_alias"
    return
  fi

  short_session_id "$session_id"
}

state_set_latest_action() {
  local cwd="$1"
  local session_id="$2"
  local event_name="$3"
  local tool_name="$4"
  local target="$5"
  local summary="$6"
  local source_value="$7"
  local path tmp
  state_init "$cwd"
  path="$(state_path "$cwd")"
  tmp="$(mktemp)"
  jq --arg sid "$session_id" --arg event "$event_name" --arg tool "$tool_name" --arg target "$target" --arg summary "$summary" --arg source "$source_value" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    .sessions = (.sessions // {})
    | .sessions[$sid].latestAction = {
        event: $event,
        toolName: $tool,
        target: $target,
        summary: $summary,
        source: $source,
        updatedAt: $now
      }
  ' "$path" > "$tmp"
  mv "$tmp" "$path"
}

state_get_recent_action_summary() {
  local cwd="$1"
  local session_id="$2"
  local max_age_seconds="$3"
  state_init "$cwd"
  jq -r --arg sid "$session_id" --argjson max_age "$max_age_seconds" --arg now "$(date -u +%s)" '
    (.sessions[$sid].latestAction // {}) as $action
    | if (($action.summary // "") == "" or ($action.updatedAt // "") == "") then
        ""
      else
        ($action.updatedAt | strptime("%Y-%m-%dT%H:%M:%SZ") | mktime) as $updated
        | if (($now | tonumber) - $updated) <= $max_age then $action.summary else "" end
      end
  ' "$(state_path "$cwd")"
}
