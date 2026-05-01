# Claude-Hark Design

## Summary
Claude-Hark is an open-source Claude Code companion that sends system notifications when a session is blocked on either a permission request or a user choice. It targets multi-threaded usage where the operator may be looking at other Claude sessions or other applications when a thread stalls.

The first version is distributed as a git project and implemented with Claude Code hooks plus a local toolkit. Hooks are the only reliable event source for `PermissionRequest` and `Elicitation`, so they remain the runtime entrypoint. Local scripts handle alias resolution, purpose inference, notification delivery, and diagnostics.

## Goals
- Notify the user when Claude Code is blocked on `PermissionRequest`.
- Notify the user when Claude Code is blocked on `Elicitation`.
- Show a stable session identifier in notifications.
- Support automatic alias inference with manual override.
- Provide a useful short explanation of why the block happened.
- Package the solution so it can be copied and adopted by other users from a git repository.

## Non-goals for v1
- Linux or Windows notification support.
- MCP as a required runtime dependency.
- Rich history UI or dashboard.
- Reading prior chat text to recover a purpose explanation.
- Cross-device alias sync.
- Team-wide managed rollout infrastructure.

## Product shape
The product has four conceptual layers:

1. **Hooks runtime**
   - Claude Code hook entrypoints for `PermissionRequest` and `Elicitation`.
   - Reads hook payloads from stdin.
   - Delegates immediately to local toolkit scripts.

2. **Local toolkit**
   - Resolves session aliases.
   - Infers purpose fallback text.
   - Sends macOS notifications.
   - Exposes install, uninstall, alias, and doctor commands.

3. **Distribution project**
   - Public git repository.
   - Installation and uninstall scripts.
   - Example `settings.json` snippets.
   - Documentation for setup, troubleshooting, and behavior guidance.

4. **Optional UX extensions**
   - Future skill for install and diagnostics.
   - Future MCP for session inspection and alias management.
   - Not required for v1.

## Why hooks are the core runtime
The blocked state is surfaced by Claude Code hook events, not by skills or MCP. Skills require explicit invocation and cannot passively observe blocking moments. MCP can expose management APIs later, but it still needs hooks as the trigger path. For that reason, v1 is hook-first, with a git-distributed toolkit around it.

## Blocking events
### PermissionRequest
Triggered when Claude needs user approval for a tool call. The hook payload reliably includes:
- `session_id`
- `tool_name`
- `tool_input`

This event is sufficient to derive a session label and a short fallback purpose explanation.

### Elicitation
Triggered when Claude is waiting for the user to answer a structured question or make a choice. The payload may not always provide a stable, rich question body, so v1 treats it as a generic “waiting for user choice” event with session-aware labeling.

## User experience
### Notification goals
Each notification should answer three questions quickly:
1. Which thread is blocked?
2. What is it waiting for?
3. Why did it stop here?

### Notification examples
- `[deploy-watch] 等待权限：Bash；目的：运行验证命令确认当前步骤`
- `[web:fix-login] 等待你的选择`
- `[sess:ab12cd34] 等待权限：Read；目的：读取上下文继续分析`

### Behavioral guidance for Claude
To improve accuracy beyond hook inference, users should add a standing instruction for Claude:

> 在请求用户批准权限或要求用户做选择前，先用一句中文说明这一步的目的；如果是执行计划中的某一步，要说明它在当前步骤中的作用。

This instruction is not the runtime notification system. It improves the conversational layer. The hook layer remains the reliable fallback.

## Alias design
### Requirements
- Alias should be available automatically with no setup.
- Alias should remain stable within a session.
- Alias should be overrideable manually.
- Fallback should always exist even with poor context.

### Resolution priority
Alias is resolved in this order:
1. Manual alias stored for the session.
2. Cached automatic alias stored for the session.
3. Repository basename plus current branch name.
4. Current working directory basename.
5. Short `session_id` such as `sess:ab12cd34`.

### Automatic alias policy
v1 uses deterministic rules instead of model-generated summaries. This avoids drift, keeps behavior reproducible, and reduces moving parts. If a repository and branch are present, the preferred automatic alias is `<repo>:<branch>`. If no git context is available, the cwd basename is used.

### Alias persistence
Aliases are stored in a local JSON file managed by the toolkit. The schema is intentionally simple:

```json
{
  "sessions": {
    "<full-session-id>": {
      "alias": "deploy-watch",
      "source": "manual",
      "updatedAt": "2026-04-28T12:00:00Z"
    }
  }
}
```

`source` is either `manual` or `auto`. Automatic aliases are cached after first resolution so later notifications remain stable.

## Purpose explanation design
### Strategy
v1 uses a hybrid model:
1. Claude should proactively explain its purpose in normal chat before asking for permission or a choice.
2. Hooks generate a fallback purpose summary for notifications.

The notification system does not attempt to parse prior chat text in v1.

### PermissionRequest fallback inference
Purpose is inferred from `tool_name` and selected `tool_input` fields.

#### Tool-based rules
- `Read` → `读取上下文继续分析`
- `Glob` or `Grep` → `搜索相关代码位置`
- `Edit` or `Write` → `修改文件执行当前步骤`
- `WebSearch` or `WebFetch` → `获取外部资料继续任务`
- other tools → `继续当前任务`

#### Bash-specific rules
If `tool_name` is `Bash`, inspect the command text:
- test-like commands (`test`, `vitest`, `jest`, `pytest`) → `运行验证命令确认当前结果`
- build-like commands (`build`, `tsc`, `compile`) → `运行构建检查当前结果`
- git-inspection commands (`git status`, `git diff`, `git log`, `git show`) → `检查当前仓库状态`
- otherwise → `执行当前步骤需要的命令`

### Elicitation fallback inference
v1 does not depend on a question-body schema. The fallback explanation is generic and flow-oriented:
- `等待你做选择以继续当前任务`
- `等待你确认实现方向`
- `等待你补充需求细节`

The exact template can remain configurable, but the default should stay short.

## Runtime architecture
### Hook entrypoint
The repository ships a single hook script entrypoint, for example `hooks/notify-blocked.sh`, which receives the event kind as an argument and the event payload on stdin.

Responsibilities:
- read event payload
- extract `session_id`
- resolve alias
- resolve purpose
- format message
- send macOS notification
- optionally emit a `systemMessage` back to Claude Code for local visibility

The hook entrypoint should stay thin. Business logic belongs in reusable library scripts.

### Local toolkit modules
Recommended module split:
- `lib/common.sh` — shared shell helpers
- `lib/alias-store.sh` — JSON read/write for alias persistence
- `lib/alias-resolver.sh` — automatic alias resolution and fallback policy
- `lib/purpose-resolver.sh` — event- and tool-based purpose inference
- `lib/notify-macos.sh` — notification transport via `osascript`

### CLI surface
A single CLI entrypoint should expose:
- `claude-hark install`
- `claude-hark uninstall`
- `claude-hark doctor`
- `claude-hark alias set <session_id> <alias>`
- `claude-hark alias clear <session_id>`
- `claude-hark alias get <session_id>`
- `claude-hark alias list`

This keeps the product namespace cohesive and leaves room for future subcommands.

## Configuration
### Claude Code settings integration
v1 integrates through user-level or local settings hooks. The recommended default is user-level configuration so the behavior applies across projects.

Hook events to register:
- `PermissionRequest`
- `Elicitation`

A representative settings fragment:

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

The exact install path may vary, but the product should document one canonical default.

### Product config
The toolkit may carry a small internal config file. The effective v1 configuration model is:

```json
{
  "enabled": true,
  "platform": "macos",
  "alias": {
    "mode": "auto-with-override",
    "fallback": "session-id"
  },
  "notifications": {
    "permissionRequest": true,
    "elicitation": true
  },
  "purpose": {
    "mode": "hybrid-fallback",
    "bashClassification": true
  }
}
```

This should stay intentionally small in v1.

## Repository structure
```text
claude-hark/
├── README.md
├── install.sh
├── uninstall.sh
├── hooks/
│   └── notify-blocked.sh
├── bin/
│   └── claude-hark
├── lib/
│   ├── alias-store.sh
│   ├── alias-resolver.sh
│   ├── purpose-resolver.sh
│   ├── notify-macos.sh
│   └── common.sh
├── examples/
│   ├── settings.global.json
│   ├── settings.local.json
│   └── CLAUDE.md.snippet
└── docs/
    ├── architecture.md
    ├── configuration.md
    └── troubleshooting.md
```

## Install experience
### Manual path
Users can:
1. clone the repository
2. run `install.sh`
3. review and merge the suggested hook snippet into `~/.claude/settings.json`
4. add the recommended Claude instruction snippet if desired

### Assisted path
The install script may optionally patch `~/.claude/settings.json`, but documentation should also include a manual review path. The product should be transparent about what it writes and where.

## Diagnostics
`claude-hark doctor` should validate:
- required files exist
- alias store is readable and writable
- `jq` is available
- `osascript` is available
- Claude settings contain expected hook entries
- a test notification can be sent

This command is important because hook failures are otherwise hard to observe.

## Security and privacy
- Alias storage is local-only in v1.
- No remote service is required.
- Notification text should stay short and avoid leaking unnecessary file contents.
- Commands should quote all shell arguments safely.
- Hook scripts should avoid brittle parsing and prefer `jq` for payload extraction.

## Rollout plan
### v1
- macOS notifications
- hook integration
- automatic aliasing with manual override
- fallback purpose inference
- CLI install and diagnostics

### Later enhancements
- purpose cache that reuses Claude’s latest explicit explanation
- Linux and Windows notifiers
- optional skill for install, doctor, and alias management
- optional MCP for session state inspection

## Success criteria
v1 is successful if:
- users receive a system notification whenever Claude is blocked on permission or a choice
- the notification clearly identifies the blocked session
- alias behavior is useful without setup and correctable when needed
- permission notifications include a short reason that helps the user decide whether to return attention to that session

## Open extension points
These are intentionally left for future versions, not unresolved v1 requirements:
- richer elicitation message extraction
- history of blocked events
- MCP-backed management API
- shared alias conventions across teams
