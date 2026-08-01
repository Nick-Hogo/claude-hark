#!/usr/bin/env bash
set -euo pipefail
# This test verifies the stable documentation contract and current-spec ownership.
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

spec="$repo_root/docs/spec/current-spec.md"
[[ -f "$spec" ]] || fail 'current product spec is missing'

spec_content="$(cat "$spec")"
assert_contains "$spec_content" 'Status: CURRENT'

extract_block() {
  local name="$1"
  awk "/<!-- ${name}:BEGIN -->/{inside=1; next} /<!-- ${name}:END -->/{inside=0} inside" "$spec"
}

for block in EVENT-MATRIX SUPPORT-MATRIX RELEASE-GATE; do
  assert_contains "$spec_content" "<!-- ${block}:BEGIN -->"
  assert_contains "$spec_content" "<!-- ${block}:END -->"
done

event_block="$(extract_block EVENT-MATRIX)"
events=(
  user-prompt-submit
  pre-tool-use
  post-tool-use
  post-tool-use-failure
  permission
  notification
  elicitation
  stop
  stop-failure
)
for event in "${events[@]}"; do
  count="$(printf '%s\n' "$event_block" | grep -F -c "\`$event\`" || true)"
  assert_eq '1' "$count"
done
event_rows="$(printf '%s\n' "$event_block" | grep -E -c '^\| `[^`]+` \|' || true)"
assert_eq '9' "$event_rows"
for heading in 'Record' 'Status' 'System notification' 'Dashboard lane' 'Session namer'; do
  assert_contains "$event_block" "$heading"
done
expected_event_rows=(
  '| `user-prompt-submit` | latest + history | active | No | Active | No |'
  '| `pre-tool-use` | latest + history | active | No | Active | Optional, first eligible event |'
  '| `post-tool-use` | latest + history | active | No | Active | No |'
  '| `post-tool-use-failure` | latest + history | active | No | Active | No |'
  '| `permission` | latest + history | notified | Yes | Tasks | No |'
  '| `notification` | latest + history; only `permission_prompt` | active | No duplicate | Active | No |'
  '| `elicitation` | latest + history | notified | Yes | Tasks | No |'
  '| `stop` | latest + history | waiting_for_user | No | Review | No |'
  '| `stop-failure` | latest + history | failed | No | Review | No |'
)
for row in "${expected_event_rows[@]}"; do
  assert_contains "$event_block" "$row"
done

support_block="$(extract_block SUPPORT-MATRIX)"
assert_contains "$support_block" '| macOS | Stable |'
assert_contains "$support_block" '| Linux desktop | Experimental |'
assert_contains "$support_block" '| WSL | Experimental |'
assert_contains "$support_block" '| Native Windows | Experimental |'

release_block="$(extract_block RELEASE-GATE)"
release_items="$(printf '%s\n' "$release_block" | grep -E -c '^- \[ \] RG-[0-9]+:' || true)"
assert_eq '7' "$release_items"
assert_contains "$release_block" 'Verification:'

readme_content="$(cat "$repo_root/README.md")"
assert_contains "$readme_content" 'docs/spec/current-spec.md'
assert_contains "$readme_content" 'docs/configuration.md'
assert_not_contains "$readme_content" '**仅支持 macOS**'
assert_not_contains "$readme_content" 'Windows / Linux 桌面通知支持'

current_count="$(grep -R --include='*.md' -l 'Status: CURRENT' "$repo_root/docs" | wc -l | tr -d ' ')"
assert_eq '1' "$current_count"

assert_contains "$(head -8 "$repo_root/docs/superpowers/specs/2026-04-28-claude-hark-design.md")" 'SUPERSEDED'
assert_contains "$(head -8 "$repo_root/docs/superpowers/plans/2026-04-28-claude-hark.md")" 'SUPERSEDED'
assert_contains "$(head -8 "$repo_root/docs/test-analysis.md")" 'POINT-IN-TIME'

archive_index="$repo_root/docs/superpowers/README.md"
[[ -f "$archive_index" ]] || fail 'historical documentation index is missing'
assert_contains "$(cat "$archive_index")" 'docs/spec/current-spec.md'
assert_contains "$spec_content" 'docs/superpowers/README.md'

# Compare the canonical JSON example with the installer's generated Hook contract.
tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
install_root="$tmp_dir/install-root"
settings_path="$tmp_dir/settings.json"
profile_path="$tmp_dir/profile"
printf '{"hooks":{}}\n' > "$settings_path"
CLAUDE_HARK_INSTALL_ROOT="$install_root" \
CLAUDE_HARK_SETTINGS_PATH="$settings_path" \
CLAUDE_HARK_SHELL_PROFILE="$profile_path" \
  bash "$repo_root/install.sh" >/dev/null
python3 - "$repo_root/docs/configuration.md" "$settings_path" "$install_root" <<'PY'
import json
import re
import sys
from pathlib import Path

configuration = Path(sys.argv[1]).read_text()
match = re.search(r"```json\n(.*?)\n```", configuration, re.S)
if not match:
    raise SystemExit("canonical Hook JSON block is missing")
documented = json.loads(match.group(1))["hooks"]
generated = json.loads(Path(sys.argv[2]).read_text())["hooks"]
install_root = sys.argv[3]

def normalize(value):
    if isinstance(value, dict):
        return {key: normalize(item) for key, item in value.items()}
    if isinstance(value, list):
        return [normalize(item) for item in value]
    if isinstance(value, str):
        return value.replace(install_root, "~/.claude-hark")
    return value

if normalize(generated) != documented:
    raise SystemExit("configuration Hook JSON differs from installer output")
PY

printf 'test_doc_contract.sh: PASS\n'
