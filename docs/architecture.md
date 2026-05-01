# Architecture

Claude-Hark 的核心调用模型是：

```text
Hook → State → Summary → Notify
```

它通过 Claude Code hooks 捕获关键生命周期事件，基于 `session_id` 建立稳定会话身份，在项目本地持久化每个 session 的最近操作上下文，并通过系统通知把“Agent 正在做什么、为什么需要你介入”展示给用户。

## Core modules

- `hooks/claude-hark.sh` — 唯一主 hook 入口，负责读取 hook payload 并串联后续模块。
- `hooks/notify-blocked.sh` — 兼容旧入口，直接委托给 `claude-hark.sh`。
- `lib/session-state.sh` — 管理 session alias 和 latest action，默认写入 `<project>/.claude-hark/state.json`。
- `lib/action-summary.sh` — 提取 `tool_name` / `tool_input` / file / command，生成 action summary；支持规则 fallback 和可选外部 summarizer。
- `lib/notifier.sh` — 通知统一入口，根据系统选择通知实现。
- `lib/notify-macos.sh` — macOS 通知实现，使用 `osascript`。

## Runtime flow

### PreToolUse

`PreToolUse(Edit|Write|Bash)` 更新 session state 中的 latest action，不默认通知用户。

```text
PreToolUse
  → hooks/claude-hark.sh
  → session-state.sh
  → action-summary.sh
  → <project>/.claude-hark/state.json
```

### PermissionRequest

`PermissionRequest(Edit|Write|Bash|mcp__.*)` 优先读取最近 action summary；没有可用 summary 时现场生成 fallback，然后发送通知。

```text
PermissionRequest
  → hooks/claude-hark.sh
  → session-state.sh
  → action-summary.sh
  → notifier.sh
  → notify-macos.sh
```

### Elicitation

`Elicitation` 生成等待用户选择的 summary 并发送通知。

## State location

默认状态文件在当前项目目录下：

```text
<project>/.claude-hark/state.json
```

如果设置了 `CLAUDE_HARK_HOME`，则使用该目录，主要用于测试或强制自定义存储位置。

## Optional summarizer

默认不调用 LLM。配置 `CLAUDE_HARK_SUMMARIZER_COMMAND` 后，`action-summary.sh` 会把截断和脱敏后的 payload 传给外部命令，并将输出作为展示文本。失败、超时、空输出或递归保护触发时都会回退到本地规则。
