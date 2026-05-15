# Architecture

Claude-Hark 的核心调用模型是：

```text
Hook → State → Structured Context → Session Namer → LLM Summary → Fallback Rules → Notify
```

它通过 Claude Code hooks 捕获关键生命周期事件，基于 `session_id` 建立稳定会话身份，在项目本地持久化每个 session 的最近操作上下文，并通过系统通知把“Agent 正在做什么、为什么需要你介入”展示给用户。

## Core modules

- `hooks/claude-hark.sh` — 唯一主 hook 入口，负责读取 hook payload 并串联后续模块。
- `lib/session-state.sh` — 管理 session alias 和 latest action，默认写入 `<project>/.claude-hark/state.json`。
- `lib/action_summary.py` — 提取结构化 hook context，优先调用 prompt-mode LLM summarizer，失败时回退到本地规则，并格式化通知正文。
- `lib/notifier.sh` — 通知统一入口，根据系统选择通知实现。
- `lib/notify-macos.sh` — macOS 通知实现，优先使用 `terminal-notifier`，并回退到 `osascript`。

## Runtime flow

### UserPromptSubmit / PreToolUse / PostToolUse / PostToolUseFailure

`UserPromptSubmit`、`PreToolUse(Edit|Write|Bash)`、`PostToolUse`、`PostToolUseFailure` 会把 session 标记为进行中，用于 dashboard 的「进行中」面板。`PreToolUse` 仍会更新 latest action，供后续权限请求复用；若配置了 `CLAUDE_HARK_SESSION_NAMER_COMMAND`，且当前 session 还没有手动或 AI alias，这一步也会尝试生成 session alias 和 description。

```text
UserPromptSubmit / PreToolUse / PostToolUse / PostToolUseFailure
  → hooks/claude-hark.sh
  → session-state.sh
  → action_summary.py
  → <project>/.claude-hark/state.json
  → Dashboard: 进行中
```

### PermissionRequest / Notification(permission_prompt)

`PermissionRequest(Edit|Write|Bash|mcp__.*)` 优先读取最近 action summary；没有可用 summary 时现场生成 fallback，然后发送通知。`Notification(permission_prompt)` 走同一条记录路径，用于覆盖 Claude Code 只发权限提示通知的场景。

```text
PermissionRequest / Notification(permission_prompt)
  → hooks/claude-hark.sh
  → session-state.sh
  → action_summary.py
  → notifier.sh
  → notify-macos.sh
  → Dashboard: 任务面板
```

### Elicitation

`Elicitation` 生成等待用户选择的 summary 并发送通知，也归入 dashboard 的「任务面板」。

### Stop / StopFailure

`Stop` 表示 Claude 已完成本轮响应并等待用户下一步输入，归入 dashboard 的「待回顾」面板。`StopFailure` 表示当前 turn 异常结束，同样进入「待回顾」，方便用户检查失败原因后再继续。

```text
Stop / StopFailure
  → hooks/claude-hark.sh
  → session-state.sh
  → <project>/.claude-hark/state.json
  → Dashboard: 待回顾
```

## State location

默认状态文件在当前项目目录下：

```text
<project>/.claude-hark/state.json
```

如果设置了 `CLAUDE_HARK_HOME`，则使用该目录，主要用于测试或强制自定义存储位置。

每个 session 会维护：

- `alias` — 通知中显示的 session 名称，来源可能是 `manual`、`ai` 或 `auto`。
- `description` — session 的简短说明，通常由 AI namer 或 CLI 手动写入。
- `latestAction` — 最近一次动作摘要，用于权限请求复用；同时写入 `status` 和 `display` 作为 dashboard 展开页 view model。
- `hookEvents` — 最近 100 条 hook 日志，包含 `event`、`toolName`、`target`、`purpose`、`summary`、`status`、`source`、`display`、`recordedAt`，用于追踪“为什么触发通知/等待”。
- `display` — dashboard 展开页使用的结构化 AI 判断数据，包含 `title`、`purpose`、`details`、`suggestion`、`review`、`body`、`aiInput`，通知类事件还会保存实际 `renderedBody`。

Dashboard 的 `SessionDetailPage` 会读取每条 `hookEvents[].display` 并展示每一步操作的 AI 判断；旧 state 中没有 `display` 的历史事件仍只显示基础事件字段。

## Optional session namer

默认不调用 AI 生成 session 名称。配置 `CLAUDE_HARK_SESSION_NAMER_COMMAND` 后，`action_summary.py` 会把首个 `PreToolUse` 的上下文脱敏和截断后发给外部命令，并期望得到 `{"name":"...","description":"..."}`。外部命令失败、超时、空输出、递归保护触发或返回无效 JSON 时都会保留 `<repo>:<branch>` / `<repo>` 的本地 fallback。手动 alias 不会被覆盖。

## Optional summarizer

默认不调用 LLM。配置 `CLAUDE_HARK_SUMMARIZER_COMMAND` 后，`action_summary.py` 会先把 hook payload 提取为结构化 context，并在默认 `prompt` 模式下把 context 包装成摘要 prompt 发给外部命令。外部命令失败、超时、空输出或递归保护触发时都会回退到本地规则。

如果设置 `CLAUDE_HARK_SUMMARIZER_INPUT_MODE=payload`，则保持旧行为：只把截断和脱敏后的 JSON payload 传给外部命令。
