#!/usr/bin/env bash
set -euo pipefail

# ---- 安装路径配置 ----
repo_root="$(cd "$(dirname "$0")" && pwd)"
install_root="${CLAUDE_HARK_INSTALL_ROOT:-$HOME/.claude-hark}"
settings_path="${CLAUDE_HARK_SETTINGS_PATH:-$HOME/.claude/settings.json}"
shell_profile="${CLAUDE_HARK_SHELL_PROFILE:-}"

# ---- 复制运行文件 ----
mkdir -p "$install_root/hooks" "$install_root/bin" "$install_root/lib"
cp "$repo_root/hooks/claude-hark.sh" "$install_root/hooks/claude-hark.sh"
cp "$repo_root/bin/claude-hark" "$install_root/bin/claude-hark"
cp "$repo_root/lib/common.sh" "$install_root/lib/common.sh"
cp "$repo_root/lib/session-state.sh" "$install_root/lib/session-state.sh"
cp "$repo_root/lib/notifier.sh" "$install_root/lib/notifier.sh"
cp "$repo_root/lib/notify-macos.sh" "$install_root/lib/notify-macos.sh"
cp "$repo_root/lib/notify-windows.sh" "$install_root/lib/notify-windows.sh"
cp "$repo_root/lib/action_summary.py" "$install_root/lib/action_summary.py"
cp "$repo_root/lib/hook_context.py" "$install_root/lib/hook_context.py"
cp "$repo_root/lib/hook_handlers.py" "$install_root/lib/hook_handlers.py"
cp "$repo_root/lib/llm_provider.py" "$install_root/lib/llm_provider.py"
cp "$repo_root/lib/session_namer.py" "$install_root/lib/session_namer.py"
cp "$repo_root/lib/util.py" "$install_root/lib/util.py"
rm -rf "$install_root/dashboard"
cp -R "$repo_root/dashboard" "$install_root/dashboard"
chmod +x "$install_root/hooks/claude-hark.sh" "$install_root/bin/claude-hark" "$install_root/lib/action_summary.py"

# ---- 写入 Claude Code hooks 配置 ----
python3 - <<'PY' "$settings_path" "$install_root"
import json, pathlib, sys
settings_path = pathlib.Path(sys.argv[1])
install_root = pathlib.Path(sys.argv[2])
settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
hooks = settings.setdefault("hooks", {})
hooks["UserPromptSubmit"] = [{
    "hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh user-prompt-submit", "timeout": 5}],
}]
hooks["PreToolUse"] = [{
    "matcher": "Edit|Write|Bash",
    "hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh pre-tool-use", "timeout": 5}],
}]
hooks["PostToolUse"] = [{
    "matcher": "Edit|Write|Bash|Read|Grep|Glob|mcp__.*",
    "hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh post-tool-use", "timeout": 5}],
}]
hooks["PostToolUseFailure"] = [{
    "matcher": "Edit|Write|Bash|Read|Grep|Glob|mcp__.*",
    "hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh post-tool-use-failure", "timeout": 5}],
}]
hooks["PermissionRequest"] = [{
    "matcher": "Edit|Write|Bash|mcp__.*",
    "hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh permission", "timeout": 30}],
}]
hooks["Notification"] = [{
    "matcher": "permission_prompt",
    "hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh notification", "timeout": 5}],
}]
hooks["Elicitation"] = [{"hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh elicitation", "timeout": 5}]}]
hooks["Stop"] = [{"hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh stop", "timeout": 5}]}]
hooks["StopFailure"] = [{"hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh stop-failure", "timeout": 5}]}]
settings_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + "\n")
PY

# ---- 配置 CLI PATH ----
if [[ -z "$shell_profile" ]]; then
  case "${SHELL:-}" in
    */zsh) shell_profile="$HOME/.zshrc" ;;
    */bash) shell_profile="$HOME/.bashrc" ;;
  esac
fi

path_line="export PATH=\"$install_root/bin:\$PATH\""
if [[ -n "$shell_profile" ]]; then
  touch "$shell_profile"
  if ! grep -Fqx "$path_line" "$shell_profile"; then
    printf '\n%s\n' "$path_line" >> "$shell_profile"
  fi
fi

# ---- 安装结果提示 ----
echo "Installed to $install_root"
if [[ -n "$shell_profile" ]]; then
  echo "Added $install_root/bin to PATH in $shell_profile"
  echo "Restart your shell or run: source $shell_profile"
else
  echo "Add $install_root/bin to your PATH to use claude-hark directly"
fi
