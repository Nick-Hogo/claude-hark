# Claude-Hark Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a hook-driven macOS notification toolkit for Claude Code that reports blocked `PermissionRequest` and `Elicitation` sessions, shows stable session aliases, and provides fallback purpose summaries for permission requests.

**Architecture:** Keep the hook entrypoint thin and move logic into focused shell modules for alias storage, alias resolution, purpose inference, and macOS notification delivery. Ship the project as a standalone git repository with a single CLI entrypoint for install, uninstall, diagnostics, and alias management.

**Tech Stack:** POSIX shell with zsh/bash-compatible scripts, `jq` for JSON parsing, `osascript` for macOS notifications, Claude Code hook integration via `settings.json`.

---

## File structure

- Create: `README.md` — project overview, install flow, usage, limitations.
- Create: `install.sh` — copies scripts into the chosen install root and prints or optionally applies hook configuration.
- Create: `uninstall.sh` — removes installed scripts and leaves settings cleanup instructions.
- Create: `hooks/notify-blocked.sh` — hook entrypoint for `PermissionRequest` and `Elicitation`.
- Create: `bin/claude-hark` — CLI entrypoint for install, uninstall, doctor, and alias subcommands.
- Create: `lib/common.sh` — shared shell helpers for path resolution, JSON output, and failure messaging.
- Create: `lib/alias-store.sh` — read and write the alias JSON store.
- Create: `lib/alias-resolver.sh` — resolve aliases from manual store, cached auto values, git context, cwd, and short session id.
- Create: `lib/purpose-resolver.sh` — infer fallback purpose strings from hook event payloads.
- Create: `lib/notify-macos.sh` — send a notification with escaped content through `osascript`.
- Create: `examples/settings.global.json` — example user-level hooks configuration.
- Create: `examples/settings.local.json` — example local-project hooks configuration.
- Create: `examples/CLAUDE.md.snippet` — suggested standing instruction for Claude purpose explanations.
- Create: `docs/architecture.md` — concise architecture explanation for contributors.
- Create: `docs/configuration.md` — configuration reference and example hook wiring.
- Create: `docs/troubleshooting.md` — doctor checks and common failures.
- Create: `tests/test_layout.sh` — shell-based assertions for required project paths.
- Create: `tests/test_alias_store.sh` — shell-based assertions for alias persistence.
- Create: `tests/test_alias_resolver.sh` — shell-based assertions for alias behavior.
- Create: `tests/test_purpose_resolver.sh` — shell-based assertions for purpose inference.
- Create: `tests/test_notify_macos.sh` — shell-based assertions for notification transport.
- Create: `tests/test_notify_blocked.sh` — shell-based assertions for hook output formatting using a stub notifier.
- Create: `tests/test_cli.sh` — shell-based assertions for alias CLI and doctor basics.
- Create: `tests/test_install.sh` — shell-based assertions for install behavior.
- Create: `tests/test_helpers.sh` — shared shell test helpers.
- Create: `tests/run.sh` — test runner that executes all shell test scripts.

## Implementation notes

- Use `#!/usr/bin/env bash` for scripts that rely on arrays and `[[ ... ]]`, and avoid shell features unavailable on default macOS bash when practical.
- Store local runtime data under `~/.claude-hark/` by default:
  - `aliases.json`
  - `config.json`
- Keep hook logic side-effect free except for alias cache updates and notification delivery.
- For tests, support dependency injection through environment variables so notifier and storage locations can be redirected into temporary directories.
- Emit compact JSON from hook scripts when returning `systemMessage` to Claude Code.

### Task 1: Scaffold the repository structure

**Files:**
- Create: `README.md`
- Create: `install.sh`
- Create: `uninstall.sh`
- Create: `hooks/notify-blocked.sh`
- Create: `bin/claude-hark`
- Create: `lib/common.sh`
- Create: `lib/alias-store.sh`
- Create: `lib/alias-resolver.sh`
- Create: `lib/purpose-resolver.sh`
- Create: `lib/notify-macos.sh`
- Create: `examples/settings.global.json`
- Create: `examples/settings.local.json`
- Create: `examples/CLAUDE.md.snippet`
- Create: `docs/architecture.md`
- Create: `docs/configuration.md`
- Create: `docs/troubleshooting.md`
- Create: `tests/run.sh`
- Create: `tests/test_helpers.sh`
- Test: `tests/run.sh`

- [ ] **Step 1: Write the failing smoke test for project layout**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

required_paths=(
  "$repo_root/README.md"
  "$repo_root/install.sh"
  "$repo_root/uninstall.sh"
  "$repo_root/hooks/notify-blocked.sh"
  "$repo_root/bin/claude-hark"
  "$repo_root/lib/common.sh"
  "$repo_root/lib/alias-store.sh"
  "$repo_root/lib/alias-resolver.sh"
  "$repo_root/lib/purpose-resolver.sh"
  "$repo_root/lib/notify-macos.sh"
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/run.sh`
Expected: FAIL with `missing required path:` for the first uncreated file.

- [ ] **Step 3: Create the minimal repository skeleton and docs placeholders with real content**

```markdown
# Claude-Hark

Claude-Hark adds macOS notifications for Claude Code sessions blocked on permission requests or user choices.
```

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "install not implemented yet"
exit 1
```

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "uninstall not implemented yet"
exit 1
```

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "notify-blocked not implemented yet"
exit 1
```

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "claude-hark not implemented yet"
exit 1
```

```bash
#!/usr/bin/env bash
set -euo pipefail

project_root() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}
```

```markdown
# Architecture

The hook entrypoint is intentionally thin and delegates alias resolution, purpose inference, and notification delivery to separate shell modules.
```

- [ ] **Step 4: Add the test runner and verify layout test execution**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
```

```bash
#!/usr/bin/env bash
set -euo pipefail

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local expected="$1"
  local actual="$2"
  [[ "$expected" == "$actual" ]] || fail "expected [$expected] got [$actual]"
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/run.sh`
Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add README.md install.sh uninstall.sh hooks/notify-blocked.sh bin/claude-hark lib/common.sh lib/alias-store.sh lib/alias-resolver.sh lib/purpose-resolver.sh lib/notify-macos.sh examples/settings.global.json examples/settings.local.json examples/CLAUDE.md.snippet docs/architecture.md docs/configuration.md docs/troubleshooting.md tests/run.sh tests/test_helpers.sh tests/test_layout.sh
git commit -m "chore: scaffold blocked notifier project"
```

### Task 2: Build and test alias storage primitives

**Files:**
- Modify: `lib/common.sh`
- Modify: `lib/alias-store.sh`
- Modify: `tests/test_helpers.sh`
- Create: `tests/test_alias_store.sh`
- Modify: `tests/run.sh`
- Test: `tests/test_alias_store.sh`

- [ ] **Step 1: Write the failing alias store tests**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/common.sh"
source "$repo_root/lib/alias-store.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_HOME="$tmp_dir"

alias_store_init
assert_eq '{}' "$(cat "$CLAUDE_HARK_HOME/aliases.json")"

alias_store_set "session-1" "deploy-watch" "manual"
assert_eq 'deploy-watch' "$(alias_store_get_alias "session-1")"
assert_eq 'manual' "$(alias_store_get_source "session-1")"

alias_store_set "session-2" "web:fix-login" "auto"
assert_eq 'web:fix-login' "$(alias_store_get_alias "session-2")"

alias_store_clear "session-1"
assert_eq '' "$(alias_store_get_alias "session-1")"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_alias_store.sh`
Expected: FAIL with `alias_store_init: command not found`.

- [ ] **Step 3: Implement common path helpers and alias store functions**

```bash
#!/usr/bin/env bash
set -euo pipefail

notifier_home() {
  if [[ -n "${CLAUDE_HARK_HOME:-}" ]]; then
    printf '%s\n' "$CLAUDE_HARK_HOME"
  else
    printf '%s\n' "$HOME/.claude-hark"
  fi
}

alias_store_path() {
  printf '%s/aliases.json\n' "$(notifier_home)"
}

ensure_notifier_home() {
  mkdir -p "$(notifier_home)"
}
```

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"

alias_store_init() {
  ensure_notifier_home
  local store
  store="$(alias_store_path)"
  [[ -f "$store" ]] || printf '{}\n' > "$store"
}

alias_store_set() {
  local session_id="$1"
  local alias_value="$2"
  local source_value="$3"
  local store
  store="$(alias_store_path)"
  alias_store_init
  tmp="$(mktemp)"
  jq --arg sid "$session_id" --arg alias "$alias_value" --arg source "$source_value" --arg now "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '
    .sessions = (.sessions // {})
    | .sessions[$sid] = {alias: $alias, source: $source, updatedAt: $now}
  ' "$store" > "$tmp"
  mv "$tmp" "$store"
}

alias_store_get_alias() {
  local session_id="$1"
  alias_store_init
  jq -r --arg sid "$session_id" '.sessions[$sid].alias // ""' "$(alias_store_path)"
}

alias_store_get_source() {
  local session_id="$1"
  alias_store_init
  jq -r --arg sid "$session_id" '.sessions[$sid].source // ""' "$(alias_store_path)"
}

alias_store_clear() {
  local session_id="$1"
  local store tmp
  store="$(alias_store_path)"
  alias_store_init
  tmp="$(mktemp)"
  jq --arg sid "$session_id" 'del(.sessions[$sid])' "$store" > "$tmp"
  mv "$tmp" "$store"
}
```

- [ ] **Step 4: Update the test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_alias_store.sh"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_alias_store.sh && bash tests/run.sh`
Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add lib/common.sh lib/alias-store.sh tests/test_helpers.sh tests/test_alias_store.sh tests/run.sh
git commit -m "feat: add alias store primitives"
```

### Task 3: Build and test alias resolution behavior

**Files:**
- Modify: `lib/alias-resolver.sh`
- Modify: `lib/alias-store.sh`
- Create: `tests/test_alias_resolver.sh`
- Modify: `tests/run.sh`
- Test: `tests/test_alias_resolver.sh`

- [ ] **Step 1: Write the failing alias resolver tests**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/common.sh"
source "$repo_root/lib/alias-store.sh"
source "$repo_root/lib/alias-resolver.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_HOME="$tmp_dir"

alias_store_set "session-manual" "deploy-watch" "manual"
assert_eq 'deploy-watch' "$(resolve_session_alias "session-manual" "/tmp/project" "")"

assert_eq 'app:feature-login' "$(resolve_session_alias "session-auto" "/tmp/app" "feature-login")"
assert_eq 'app:feature-login' "$(alias_store_get_alias "session-auto")"
assert_eq 'auto' "$(alias_store_get_source "session-auto")"

assert_eq 'sandbox' "$(resolve_session_alias "session-cwd" "/tmp/sandbox" "")"
assert_eq 'sess:session-' "$(resolve_session_alias "session-fallback" "/" "")"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_alias_resolver.sh`
Expected: FAIL with `resolve_session_alias: command not found`.

- [ ] **Step 3: Implement alias resolution and cache behavior**

```bash
#!/usr/bin/env bash
set -euo pipefail

source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/common.sh"
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/alias-store.sh"

short_session_id() {
  local session_id="$1"
  printf 'sess:%s\n' "${session_id:0:8}"
}

resolve_auto_alias() {
  local cwd="$1"
  local branch_name="$2"
  local repo_name
  repo_name="$(basename "$cwd")"

  if [[ -n "$branch_name" && "$repo_name" != "/" && "$repo_name" != "." ]]; then
    printf '%s:%s\n' "$repo_name" "$branch_name"
    return
  fi

  if [[ -n "$repo_name" && "$repo_name" != "/" && "$repo_name" != "." ]]; then
    printf '%s\n' "$repo_name"
    return
  fi

  printf ''
}

resolve_session_alias() {
  local session_id="$1"
  local cwd="$2"
  local branch_name="$3"
  local manual_or_cached auto_alias

  manual_or_cached="$(alias_store_get_alias "$session_id")"
  if [[ -n "$manual_or_cached" ]]; then
    printf '%s\n' "$manual_or_cached"
    return
  fi

  auto_alias="$(resolve_auto_alias "$cwd" "$branch_name")"
  if [[ -n "$auto_alias" ]]; then
    alias_store_set "$session_id" "$auto_alias" "auto"
    printf '%s\n' "$auto_alias"
    return
  fi

  short_session_id "$session_id"
}
```

- [ ] **Step 4: Update the test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_alias_store.sh"
bash "$repo_root/tests/test_alias_resolver.sh"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_alias_resolver.sh && bash tests/run.sh`
Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add lib/alias-resolver.sh lib/alias-store.sh tests/test_alias_resolver.sh tests/run.sh
git commit -m "feat: add session alias resolution"
```

### Task 4: Build and test permission purpose inference

**Files:**
- Modify: `lib/purpose-resolver.sh`
- Create: `tests/test_purpose_resolver.sh`
- Modify: `tests/run.sh`
- Test: `tests/test_purpose_resolver.sh`

- [ ] **Step 1: Write the failing purpose resolver tests**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/purpose-resolver.sh"

assert_eq '读取上下文继续分析' "$(infer_permission_purpose 'Read' '{}')"
assert_eq '搜索相关代码位置' "$(infer_permission_purpose 'Grep' '{}')"
assert_eq '修改文件执行当前步骤' "$(infer_permission_purpose 'Edit' '{}')"
assert_eq '运行验证命令确认当前结果' "$(infer_permission_purpose 'Bash' '{"command":"npm test"}')"
assert_eq '运行构建检查当前结果' "$(infer_permission_purpose 'Bash' '{"command":"npm run build"}')"
assert_eq '检查当前仓库状态' "$(infer_permission_purpose 'Bash' '{"command":"git status --short"}')"
assert_eq '执行当前步骤需要的命令' "$(infer_permission_purpose 'Bash' '{"command":"make sync"}')"
assert_eq '继续当前任务' "$(infer_permission_purpose 'Unknown' '{}')"
assert_eq '等待你做选择以继续当前任务' "$(infer_elicitation_purpose '{}')"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_purpose_resolver.sh`
Expected: FAIL with `infer_permission_purpose: command not found`.

- [ ] **Step 3: Implement minimal purpose inference**

```bash
#!/usr/bin/env bash
set -euo pipefail

infer_permission_purpose() {
  local tool_name="$1"
  local tool_input_json="$2"
  local command_text=""

  if [[ "$tool_name" == "Bash" ]]; then
    command_text="$(printf '%s' "$tool_input_json" | jq -r '.command // ""')"
    if [[ "$command_text" == *test* || "$command_text" == *vitest* || "$command_text" == *jest* || "$command_text" == *pytest* ]]; then
      printf '运行验证命令确认当前结果\n'
      return
    fi
    if [[ "$command_text" == *build* || "$command_text" == *tsc* || "$command_text" == *compile* ]]; then
      printf '运行构建检查当前结果\n'
      return
    fi
    if [[ "$command_text" == git\ status* || "$command_text" == git\ diff* || "$command_text" == git\ log* || "$command_text" == git\ show* ]]; then
      printf '检查当前仓库状态\n'
      return
    fi
    printf '执行当前步骤需要的命令\n'
    return
  fi

  case "$tool_name" in
    Read) printf '读取上下文继续分析\n' ;;
    Glob|Grep) printf '搜索相关代码位置\n' ;;
    Edit|Write) printf '修改文件执行当前步骤\n' ;;
    WebSearch|WebFetch) printf '获取外部资料继续任务\n' ;;
    *) printf '继续当前任务\n' ;;
  esac
}

infer_elicitation_purpose() {
  printf '等待你做选择以继续当前任务\n'
}
```

- [ ] **Step 4: Update the test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_alias_store.sh"
bash "$repo_root/tests/test_alias_resolver.sh"
bash "$repo_root/tests/test_purpose_resolver.sh"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_purpose_resolver.sh && bash tests/run.sh`
Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add lib/purpose-resolver.sh tests/test_purpose_resolver.sh tests/run.sh
git commit -m "feat: add permission purpose inference"
```

### Task 5: Build and test macOS notification delivery

**Files:**
- Modify: `lib/common.sh`
- Modify: `lib/notify-macos.sh`
- Create: `tests/test_notify_macos.sh`
- Modify: `tests/run.sh`
- Test: `tests/test_notify_macos.sh`

- [ ] **Step 1: Write the failing notifier tests**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"
source "$repo_root/lib/notify-macos.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

notify_macos 'Claude Code' '[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前结果'
assert_eq 'Claude Code|[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前结果' "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_notify_macos.sh`
Expected: FAIL with `notify_macos: command not found`.

- [ ] **Step 3: Implement stub-aware macOS notifier**

```bash
#!/usr/bin/env bash
set -euo pipefail

notify_macos() {
  local title="$1"
  local body="$2"

  if [[ -n "${CLAUDE_HARK_NOTIFY_STUB:-}" ]]; then
    printf '%s|%s\n' "$title" "$body" > "$CLAUDE_HARK_NOTIFY_STUB"
    return
  fi

  local escaped_title escaped_body
  escaped_title="${title//"/\\\"}"
  escaped_body="${body//"/\\\"}"
  osascript -e "display notification \"$escaped_body\" with title \"$escaped_title\""
}
```

- [ ] **Step 4: Update the test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_alias_store.sh"
bash "$repo_root/tests/test_alias_resolver.sh"
bash "$repo_root/tests/test_purpose_resolver.sh"
bash "$repo_root/tests/test_notify_macos.sh"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_notify_macos.sh && bash tests/run.sh`
Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add lib/common.sh lib/notify-macos.sh tests/test_notify_macos.sh tests/run.sh
git commit -m "feat: add macos notification delivery"
```

### Task 6: Build and test hook event formatting

**Files:**
- Modify: `hooks/notify-blocked.sh`
- Modify: `lib/common.sh`
- Modify: `lib/alias-resolver.sh`
- Modify: `lib/purpose-resolver.sh`
- Create: `tests/test_notify_blocked.sh`
- Modify: `tests/run.sh`
- Test: `tests/test_notify_blocked.sh`

- [ ] **Step 1: Write the failing hook integration tests**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_HOME="$tmp_dir/home"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

permission_payload='{"session_id":"session-12345678","tool_name":"Bash","tool_input":{"command":"npm test"},"cwd":"/tmp/app"}'
permission_output="$(printf '%s' "$permission_payload" | bash "$repo_root/hooks/notify-blocked.sh" permission)"
assert_eq 'Claude Code|[app] 等待权限：Bash；目的：运行验证命令确认当前结果' "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
assert_eq '{"systemMessage":"[app] 等待权限：Bash；目的：运行验证命令确认当前结果"}' "$permission_output"

elicitation_payload='{"session_id":"session-abcdefgh","cwd":"/tmp/payments"}'
elicitation_output="$(printf '%s' "$elicitation_payload" | bash "$repo_root/hooks/notify-blocked.sh" elicitation)"
assert_eq 'Claude Code|[payments] 等待你的选择' "$(cat "$CLAUDE_HARK_NOTIFY_STUB")"
assert_eq '{"systemMessage":"[payments] 等待你的选择"}' "$elicitation_output"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_notify_blocked.sh`
Expected: FAIL because the hook script exits with `not implemented yet`.

- [ ] **Step 3: Implement the hook entrypoint and message formatting**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/lib/common.sh"
source "$repo_root/lib/alias-store.sh"
source "$repo_root/lib/alias-resolver.sh"
source "$repo_root/lib/purpose-resolver.sh"
source "$repo_root/lib/notify-macos.sh"

event_kind="${1:-}"
payload="$(cat)"
session_id="$(printf '%s' "$payload" | jq -r '.session_id // ""')"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // .tool_input.cwd // "."')"
branch_name="$(printf '%s' "$payload" | jq -r '.git_branch // ""')"
alias_value="$(resolve_session_alias "$session_id" "$cwd" "$branch_name")"

if [[ "$event_kind" == "permission" ]]; then
  tool_name="$(printf '%s' "$payload" | jq -r '.tool_name // "unknown"')"
  tool_input_json="$(printf '%s' "$payload" | jq -c '.tool_input // {}')"
  purpose="$(infer_permission_purpose "$tool_name" "$tool_input_json")"
  message="[$alias_value] 等待权限：$tool_name；目的：$purpose"
else
  message="[$alias_value] 等待你的选择"
fi

notify_macos 'Claude Code' "$message"
printf '{"systemMessage":"%s"}\n' "$(printf '%s' "$message" | sed 's/"/\\"/g')"
```

- [ ] **Step 4: Update the test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_alias_store.sh"
bash "$repo_root/tests/test_alias_resolver.sh"
bash "$repo_root/tests/test_purpose_resolver.sh"
bash "$repo_root/tests/test_notify_macos.sh"
bash "$repo_root/tests/test_notify_blocked.sh"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_notify_blocked.sh && bash tests/run.sh`
Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add hooks/notify-blocked.sh lib/common.sh lib/alias-resolver.sh lib/purpose-resolver.sh tests/test_notify_blocked.sh tests/run.sh
git commit -m "feat: add blocked hook notifications"
```

### Task 7: Build and test the alias and doctor CLI

**Files:**
- Modify: `bin/claude-hark`
- Modify: `lib/common.sh`
- Modify: `lib/alias-store.sh`
- Create: `tests/test_cli.sh`
- Modify: `tests/run.sh`
- Test: `tests/test_cli.sh`

- [ ] **Step 1: Write the failing CLI tests**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

tmp_dir="$(mktemp -d)"
export CLAUDE_HARK_HOME="$tmp_dir/home"
export CLAUDE_HARK_NOTIFY_STUB="$tmp_dir/notify.log"

bash "$repo_root/bin/claude-hark" alias set session-1 deploy-watch
assert_eq 'deploy-watch' "$(bash "$repo_root/bin/claude-hark" alias get session-1)"
assert_eq '' "$(bash "$repo_root/bin/claude-hark" alias clear session-1)"
assert_eq '' "$(bash "$repo_root/bin/claude-hark" alias get session-1)"

doctor_output="$(bash "$repo_root/bin/claude-hark" doctor)"
assert_contains "$doctor_output" 'jq: ok'
assert_contains "$doctor_output" 'osascript: ok'
assert_contains "$doctor_output" 'alias store: ok'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_cli.sh`
Expected: FAIL because the CLI exits with `not implemented yet`.

- [ ] **Step 3: Implement the alias and doctor CLI commands**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/lib/common.sh"
source "$repo_root/lib/alias-store.sh"

command_name="${1:-}"
subcommand_name="${2:-}"

case "$command_name" in
  alias)
    case "$subcommand_name" in
      set)
        alias_store_set "$3" "$4" manual
        ;;
      get)
        alias_store_get_alias "$3"
        ;;
      clear)
        alias_store_clear "$3"
        ;;
      list)
        alias_store_init
        cat "$(alias_store_path)"
        ;;
      *)
        echo "unknown alias subcommand" >&2
        exit 1
        ;;
    esac
    ;;
  doctor)
    alias_store_init
    command -v jq >/dev/null 2>&1 && echo 'jq: ok' || { echo 'jq: missing'; exit 1; }
    command -v osascript >/dev/null 2>&1 && echo 'osascript: ok' || { echo 'osascript: missing'; exit 1; }
    [[ -f "$(alias_store_path)" ]] && echo 'alias store: ok' || { echo 'alias store: missing'; exit 1; }
    ;;
  *)
    echo "unsupported command" >&2
    exit 1
    ;;
 esac
```

- [ ] **Step 4: Update the test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_alias_store.sh"
bash "$repo_root/tests/test_alias_resolver.sh"
bash "$repo_root/tests/test_purpose_resolver.sh"
bash "$repo_root/tests/test_notify_macos.sh"
bash "$repo_root/tests/test_notify_blocked.sh"
bash "$repo_root/tests/test_cli.sh"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_cli.sh && bash tests/run.sh`
Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add bin/claude-hark lib/common.sh lib/alias-store.sh tests/test_cli.sh tests/run.sh
git commit -m "feat: add notifier cli"
```

### Task 8: Build install and uninstall flows with documentation

**Files:**
- Modify: `install.sh`
- Modify: `uninstall.sh`
- Modify: `README.md`
- Modify: `examples/settings.global.json`
- Modify: `examples/settings.local.json`
- Modify: `examples/CLAUDE.md.snippet`
- Modify: `docs/configuration.md`
- Modify: `docs/troubleshooting.md`
- Modify: `docs/architecture.md`
- Create: `tests/test_install.sh`
- Modify: `tests/run.sh`
- Test: `tests/test_install.sh`

- [ ] **Step 1: Write the failing install tests**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source "$repo_root/tests/test_helpers.sh"

tmp_dir="$(mktemp -d)"
install_root="$tmp_dir/install-root"
settings_path="$tmp_dir/settings.json"
printf '{"hooks":{}}\n' > "$settings_path"

CLAUDE_HARK_INSTALL_ROOT="$install_root" \
CLAUDE_HARK_SETTINGS_PATH="$settings_path" \
bash "$repo_root/install.sh"

[[ -x "$install_root/hooks/notify-blocked.sh" ]] || fail 'hook script not installed'
[[ -x "$install_root/bin/claude-hark" ]] || fail 'cli not installed'
assert_contains "$(cat "$settings_path")" 'PermissionRequest'
assert_contains "$(cat "$settings_path")" 'Elicitation'
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_install.sh`
Expected: FAIL because `install.sh` exits with `install not implemented yet`.

- [ ] **Step 3: Implement install and uninstall scripts plus config examples**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")" && pwd)"
install_root="${CLAUDE_HARK_INSTALL_ROOT:-$HOME/.claude-hark}"
settings_path="${CLAUDE_HARK_SETTINGS_PATH:-$HOME/.claude/settings.json}"

mkdir -p "$install_root/hooks" "$install_root/bin" "$install_root/lib"
cp "$repo_root/hooks/notify-blocked.sh" "$install_root/hooks/notify-blocked.sh"
cp "$repo_root/bin/claude-hark" "$install_root/bin/claude-hark"
cp "$repo_root/lib/"*.sh "$install_root/lib/"
chmod +x "$install_root/hooks/notify-blocked.sh" "$install_root/bin/claude-hark"

python3 - <<'PY' "$settings_path" "$install_root"
import json, pathlib, sys
settings_path = pathlib.Path(sys.argv[1])
install_root = pathlib.Path(sys.argv[2])
settings = json.loads(settings_path.read_text()) if settings_path.exists() else {}
hooks = settings.setdefault("hooks", {})
hooks["PermissionRequest"] = [{"hooks": [{"type": "command", "command": f"{install_root}/hooks/notify-blocked.sh permission", "timeout": 5}]}]
hooks["Elicitation"] = [{"hooks": [{"type": "command", "command": f"{install_root}/hooks/notify-blocked.sh elicitation", "timeout": 5}]}]
settings_path.write_text(json.dumps(settings, ensure_ascii=False, indent=2) + "\n")
PY

echo "Installed to $install_root"
```

```bash
#!/usr/bin/env bash
set -euo pipefail

install_root="${CLAUDE_HARK_INSTALL_ROOT:-$HOME/.claude-hark}"
rm -rf "$install_root"
echo "Removed $install_root"
echo "Remove hook entries from ~/.claude/settings.json manually if needed"
```

```json
{
  "hooks": {
    "PermissionRequest": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude-hark/hooks/notify-blocked.sh permission",
            "timeout": 5
          }
        ]
      }
    ],
    "Elicitation": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude-hark/hooks/notify-blocked.sh elicitation",
            "timeout": 5
          }
        ]
      }
    ]
  }
}
```

```markdown
在请求用户批准权限或要求用户做选择前，先用一句中文说明这一步的目的；如果是执行计划中的某一步，要说明它在当前步骤中的作用。
```

- [ ] **Step 4: Update the test runner**

```bash
#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"

bash "$repo_root/tests/test_layout.sh"
bash "$repo_root/tests/test_alias_store.sh"
bash "$repo_root/tests/test_alias_resolver.sh"
bash "$repo_root/tests/test_purpose_resolver.sh"
bash "$repo_root/tests/test_notify_macos.sh"
bash "$repo_root/tests/test_notify_blocked.sh"
bash "$repo_root/tests/test_cli.sh"
bash "$repo_root/tests/test_install.sh"
```

- [ ] **Step 5: Run test to verify it passes**

Run: `bash tests/test_install.sh && bash tests/run.sh`
Expected: PASS with no output.

- [ ] **Step 6: Commit**

```bash
git add install.sh uninstall.sh README.md examples/settings.global.json examples/settings.local.json examples/CLAUDE.md.snippet docs/configuration.md docs/troubleshooting.md docs/architecture.md tests/test_install.sh tests/run.sh
git commit -m "feat: add install flow and docs"
```

### Task 9: Run end-to-end verification and polish contributor docs

**Files:**
- Modify: `README.md`
- Modify: `docs/troubleshooting.md`
- Modify: `docs/architecture.md`
- Test: `tests/run.sh`

- [ ] **Step 1: Add a failing contributor-facing verification checklist to README**

```markdown
## Verification

Run the full test suite before publishing:

```bash
bash tests/run.sh
```
```

- [ ] **Step 2: Run full verification and note any documentation gaps**

Run: `bash tests/run.sh`
Expected: PASS. If it fails, update the affected docs so setup and troubleshooting match actual behavior.

- [ ] **Step 3: Polish the final docs with exact usage examples**

```markdown
## Usage

```bash
claude-hark alias list
claude-hark alias set <session_id> deploy-watch
claude-hark doctor
```
```

```markdown
## Common issues

- `jq: missing` — install jq and rerun `claude-hark doctor`.
- No notification appears — verify macOS notifications are enabled for the terminal app running Claude Code.
- Hook appears idle — confirm the expected `PermissionRequest` and `Elicitation` entries exist in `~/.claude/settings.json`.
```

- [ ] **Step 4: Run full verification again**

Run: `bash tests/run.sh`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add README.md docs/troubleshooting.md docs/architecture.md
git commit -m "docs: finalize blocked notifier usage guidance"
```

## Spec coverage check

- `PermissionRequest` notifications: covered by Task 4 and Task 6.
- `Elicitation` notifications: covered by Task 6 and Task 8.
- session alias stability and manual override: covered by Task 2, Task 3, and Task 7.
- macOS notification delivery: covered by Task 5.
- git-distributed install flow: covered by Task 8 and Task 9.
- purpose explanation fallback: covered by Task 4 and Task 6.
- non-goal boundaries are respected because no task introduces MCP, skill runtime dependency, or non-macOS notification support.
