#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
install_root="${CLAUDE_HARK_INSTALL_ROOT:-$HOME/.claude-hark}"
settings_path="${CLAUDE_HARK_SETTINGS_PATH:-$HOME/.claude/settings.json}"
shell_profile="${CLAUDE_HARK_SHELL_PROFILE:-}"

mkdir -p "$install_root/hooks" "$install_root/bin" "$install_root/lib"
cp "$repo_root/hooks/claude-hark.sh" "$install_root/hooks/claude-hark.sh"
cp "$repo_root/hooks/notify-blocked.sh" "$install_root/hooks/notify-blocked.sh"
cp "$repo_root/bin/claude-hark" "$install_root/bin/claude-hark"
cp "$repo_root/lib/"*.sh "$install_root/lib/"
chmod +x "$install_root/hooks/claude-hark.sh" "$install_root/hooks/notify-blocked.sh" "$install_root/bin/claude-hark"

python3 - <<'PY' "$settings_path" "$install_root"
import json, pathlib, sys
settings_path = pathlib.Path(sys.argv[1])
install_root = pathlib.Path(sys.argv[2])
settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
hooks = settings.setdefault("hooks", {})
hooks["PreToolUse"] = [{
    "matcher": "Edit|Write|Bash",
    "hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh pre-tool-use", "timeout": 5}],
}]
hooks["PermissionRequest"] = [{
    "matcher": "Edit|Write|Bash|mcp__.*",
    "hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh permission", "timeout": 5}],
}]
hooks["Elicitation"] = [{"hooks": [{"type": "command", "command": f"{install_root}/hooks/claude-hark.sh elicitation", "timeout": 5}]}]
settings_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + "\n")
PY

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

echo "Installed to $install_root"
if [[ -n "$shell_profile" ]]; then
  echo "Added $install_root/bin to PATH in $shell_profile"
  echo "Restart your shell or run: source $shell_profile"
else
  echo "Add $install_root/bin to your PATH to use claude-hark directly"
fi
