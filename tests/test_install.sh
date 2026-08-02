#!/usr/bin/env bash
set -euo pipefail
# 验证安装文件、Hook 配置和 Claude-Hark JSON settings。

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

tmp_dir="$(mktemp -d)"
install_root="$tmp_dir/install-root"
settings_path="$tmp_dir/claude-settings.json"
app_settings_path="$install_root/settings.json"
legacy_config_path="$tmp_dir/config/claude-hark/env"
shell_profile="$tmp_dir/.zshrc"
printf '{"hooks":{}}\n' > "$settings_path"
mkdir -p "$(dirname "$legacy_config_path")"
printf '%s\n' "CLAUDE_HARK_LLM_API_KEY='old-secret'" > "$legacy_config_path"
printf '[[ -f "%s" ]] && source "%s"\n' "$legacy_config_path" "$legacy_config_path" > "$shell_profile"

CLAUDE_HARK_INSTALL_ROOT="$install_root" \
CLAUDE_HARK_SETTINGS_PATH="$settings_path" \
CLAUDE_HARK_APP_SETTINGS_PATH="$app_settings_path" \
CLAUDE_HARK_LEGACY_CONFIG_PATH="$legacy_config_path" \
CLAUDE_HARK_SHELL_PROFILE="$shell_profile" \
bash "$repo_root/install.sh"

[[ -x "$install_root/hooks/claude-hark.sh" ]] || fail 'main hook script not installed'
[[ ! -e "$install_root/hooks/notify-blocked.sh" ]] || fail 'deprecated compat hook should not be installed'
[[ -f "$install_root/lib/notify-windows.sh" ]] || fail 'windows notifier backend not installed'
[[ -f "$install_root/lib/hook_context.py" ]] || fail 'hook context module not installed'
[[ -f "$install_root/lib/hook_handlers.py" ]] || fail 'hook handlers module not installed'
[[ -f "$install_root/lib/transcript_context.py" ]] || fail 'transcript context module not installed'
[[ -f "$install_root/lib/llm_provider.py" ]] || fail 'llm provider module not installed'
[[ -f "$install_root/lib/session_namer.py" ]] || fail 'session namer module not installed'
[[ -x "$install_root/bin/claude-hark" ]] || fail 'cli not installed'
[[ -x "$install_root/bin/claude-hark-summarize" ]] || fail 'summarizer client not installed'

[[ -f "$app_settings_path" ]] || fail 'settings.json not created'
[[ "$(stat -c '%a' "$app_settings_path")" == '600' ]] || fail 'settings permissions are not 600'
jq -e '.llm == {enabled:false,provider:"openai",baseUrl:"",model:"",apiKey:"",timeoutSeconds:3}' "$app_settings_path" >/dev/null || fail 'default LLM settings are invalid'
assert_contains "$(jq -r '._comment' "$app_settings_path")" 'openai-compat'
[[ ! -e "$legacy_config_path" ]] || fail 'legacy env config should be removed'
profile_content="$(cat "$shell_profile")"
assert_contains "$profile_content" "export PATH=\"$install_root/bin:\$PATH\""
assert_not_contains "$profile_content" "$legacy_config_path"

settings_content="$(cat "$settings_path")"
for value in PreToolUse PermissionRequest Notification permission_prompt Elicitation 'Edit|Write|Bash' 'Edit|Write|Bash|mcp__.*' claude-hark.sh; do
  assert_contains "$settings_content" "$value"
done

# Reinstall preserves JSON values and keeps PATH idempotent.
jq '.llm = {enabled:true,provider:"anthropic",baseUrl:"https://gateway.example",model:"custom-model",apiKey:"user-secret",timeoutSeconds:30}' "$app_settings_path" > "$tmp_dir/custom.json"
mv "$tmp_dir/custom.json" "$app_settings_path"
CLAUDE_HARK_INSTALL_ROOT="$install_root" \
CLAUDE_HARK_SETTINGS_PATH="$settings_path" \
CLAUDE_HARK_APP_SETTINGS_PATH="$app_settings_path" \
CLAUDE_HARK_LEGACY_CONFIG_PATH="$legacy_config_path" \
CLAUDE_HARK_SHELL_PROFILE="$shell_profile" \
bash "$repo_root/install.sh" >/dev/null
assert_eq 'user-secret' "$(jq -r '.llm.apiKey' "$app_settings_path")"
assert_eq 'anthropic' "$(jq -r '.llm.provider' "$app_settings_path")"
assert_eq '1' "$(grep -Fxc "export PATH=\"$install_root/bin:\$PATH\"" "$shell_profile")"
