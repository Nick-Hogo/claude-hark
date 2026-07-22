#!/usr/bin/env bash
set -euo pipefail
# 这个脚本负责卸载 Claude-Hark 运行文件并清理相关 shell 配置。

# ---- 卸载路径配置 ----
install_root="${CLAUDE_HARK_INSTALL_ROOT:-$HOME/.claude-hark}"

# ---- 移除安装目录 ----
rm -rf "$install_root"

# ---- 卸载结果提示 ----
echo "Removed $install_root"
echo "Remove hook entries from ~/.claude/settings.json manually if needed"
