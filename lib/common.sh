#!/usr/bin/env bash
set -euo pipefail
# 这个 shell 库提供路径、目录创建和 JSON 转义等通用工具。

# ---- 通用路径与 JSON 工具 ----
# 输出当前项目根目录，供脚本定位资源文件。
project_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# 确保目标目录存在，避免后续写文件失败。
ensure_dir() {
  mkdir -p "$1"
}

# 根据环境变量或当前项目路径解析 Claude-Hark 状态目录。
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

# 将普通字符串编码成 JSON 字符串字面量。
json_escape() {
  jq -Rn --arg value "$1" '$value'
}

