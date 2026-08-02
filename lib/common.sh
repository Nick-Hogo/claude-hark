#!/usr/bin/env bash
set -euo pipefail
# 这个 shell 库提供路径、目录创建和 JSON 转义等通用工具。

# ---- 通用路径与 JSON 工具 ----
# 输出当前项目根目录，供脚本定位资源文件。
project_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

# 返回 Claude-Hark 自己的 JSON 配置路径。
hark_settings_path() {
  printf '%s\n' "${CLAUDE_HARK_APP_SETTINGS_PATH:-$(project_root)/settings.json}"
}

# 每次运行时读取 JSON 配置，不依赖 shell profile 传播环境变量。
load_hark_settings() {
  local path provider base_url model api_key timeout enabled
  path="$(hark_settings_path)"
  [[ -f "$path" ]] || return 0
  jq -e 'type == "object" and (.llm | type == "object")' "$path" >/dev/null 2>&1 || {
    printf 'Claude-Hark: invalid settings JSON: %s\n' "$path" >&2
    return 0
  }
  enabled="$(jq -r '.llm.enabled // false' "$path")"
  provider="$(jq -r '.llm.provider // "openai"' "$path")"
  base_url="$(jq -r '.llm.baseUrl // ""' "$path")"
  model="$(jq -r '.llm.model // ""' "$path")"
  api_key="$(jq -r '.llm.apiKey // ""' "$path")"
  timeout="$(jq -r '.llm.timeoutSeconds // 3' "$path")"
  export CLAUDE_HARK_LLM_PROVIDER="$provider"
  export CLAUDE_HARK_LLM_URL="$base_url"
  export CLAUDE_HARK_LLM_MODEL="$model"
  export CLAUDE_HARK_LLM_API_KEY="$api_key"
  export CLAUDE_HARK_SUMMARIZER_TIMEOUT="$timeout"
  if [[ "$enabled" == "true" && -n "$model" && -n "$api_key" ]]; then
    export CLAUDE_HARK_SUMMARIZER_COMMAND="$(project_root)/bin/claude-hark-summarize"
  else
    unset CLAUDE_HARK_SUMMARIZER_COMMAND
  fi
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

