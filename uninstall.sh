#!/usr/bin/env bash
set -euo pipefail

# ---- 卸载路径配置 ----
install_root="${CLAUDE_HARK_INSTALL_ROOT:-$HOME/.claude-hark}"

# ---- 移除安装目录 ----
rm -rf "$install_root"

# ---- 卸载结果提示 ----
echo "Removed $install_root"
echo "Remove hook entries from ~/.claude/settings.json manually if needed"
