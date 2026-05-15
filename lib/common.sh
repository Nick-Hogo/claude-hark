#!/usr/bin/env bash
set -euo pipefail

# ---- 通用路径与 JSON 工具 ----
project_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

ensure_dir() {
  mkdir -p "$1"
}

hark_home_for_cwd() {
  local cwd="${1:-}"

  if [[ -n "${CLAUDE_HARK_HOME:-}" ]]; then
    printf '%s\n' "$CLAUDE_HARK_HOME"
    return
  fi

  if [[ -n "$cwd" && "$cwd" != "null" && -d "$cwd" ]]; then
    printf '%s/.claude-hark\n' "$cwd"
    return
  fi

  printf '%s/.claude-hark\n' "$HOME"
}

json_escape() {
  jq -Rn --arg value "$1" '$value'
}

