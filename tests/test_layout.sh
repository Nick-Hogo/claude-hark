#!/usr/bin/env bash
set -euo pipefail
# 这个测试脚本验证项目关键文件和目录布局完整。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

required_paths=(
  "$repo_root/README.md"
  "$repo_root/install.sh"
  "$repo_root/uninstall.sh"
  "$repo_root/hooks/claude-hark.sh"
  "$repo_root/bin/claude-hark"
  "$repo_root/lib/common.sh"
  "$repo_root/lib/session-state.sh"
  "$repo_root/lib/action_summary.py"
  "$repo_root/lib/hook_context.py"
  "$repo_root/lib/hook_handlers.py"
  "$repo_root/lib/llm_provider.py"
  "$repo_root/lib/session_namer.py"
  "$repo_root/lib/util.py"
  "$repo_root/lib/notifier.sh"
  "$repo_root/lib/notify-macos.sh"
  "$repo_root/lib/notify-windows.sh"
  "$repo_root/examples/settings.global.json"
  "$repo_root/examples/settings.local.json"
  "$repo_root/examples/CLAUDE.md.snippet"
  "$repo_root/docs/architecture.md"
  "$repo_root/docs/configuration.md"
  "$repo_root/docs/troubleshooting.md"
)

for path in "${required_paths[@]}"; do
  [[ -e "$path" ]] || {
    printf 'missing required path: %s\n' "$path"
    exit 1
  }
done
