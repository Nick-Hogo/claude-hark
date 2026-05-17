#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

tmp_dir="$(mktemp -d)"
install_root="$tmp_dir/install-root"
settings_path="$tmp_dir/settings.json"
shell_profile="$tmp_dir/.zshrc"
printf '{"hooks":{}}\n' > "$settings_path"

CLAUDE_HARK_INSTALL_ROOT="$install_root" \
CLAUDE_HARK_SETTINGS_PATH="$settings_path" \
CLAUDE_HARK_SHELL_PROFILE="$shell_profile" \
bash "$repo_root/install.sh"

[[ -x "$install_root/hooks/claude-hark.sh" ]] || fail 'main hook script not installed'
[[ ! -e "$install_root/hooks/notify-blocked.sh" ]] || fail 'deprecated compat hook should not be installed'
[[ -f "$install_root/lib/notify-windows.sh" ]] || fail 'windows notifier backend not installed'
[[ -f "$install_root/lib/hook_context.py" ]] || fail 'hook context module not installed'
[[ -f "$install_root/lib/hook_handlers.py" ]] || fail 'hook handlers module not installed'
[[ -f "$install_root/lib/llm_provider.py" ]] || fail 'llm provider module not installed'
[[ -f "$install_root/lib/session_namer.py" ]] || fail 'session namer module not installed'
[[ -x "$install_root/bin/claude-hark" ]] || fail 'cli not installed'
settings_content="$(cat "$settings_path")"
assert_contains "$settings_content" 'PreToolUse'
assert_contains "$settings_content" 'PermissionRequest'
assert_contains "$settings_content" 'Notification'
assert_contains "$settings_content" 'permission_prompt'
assert_contains "$settings_content" 'Elicitation'
assert_contains "$settings_content" 'Edit|Write|Bash'
assert_contains "$settings_content" 'Edit|Write|Bash|mcp__.*'
assert_contains "$settings_content" 'claude-hark.sh'
profile_content="$(cat "$shell_profile")"
assert_contains "$profile_content" "export PATH=\"$install_root/bin:\$PATH\""
