#!/usr/bin/env bash
set -euo pipefail

install_root="${CLAUDE_HARK_INSTALL_ROOT:-$HOME/.claude-hark}"
rm -rf "$install_root"
echo "Removed $install_root"
echo "Remove hook entries from ~/.claude/settings.json manually if needed"
