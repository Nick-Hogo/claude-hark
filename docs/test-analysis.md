# Test Analysis

本文分析 `tests/` 目录中现有测试的覆盖目的、重复点和测试目标一致性。

## 测试结构

`tests/run.sh` 负责串行执行全部测试脚本：

| 文件 | 主要目的 | 覆盖层级 |
| --- | --- | --- |
| `tests/test_layout.sh` | 验证仓库发布所需文件存在，包括入口脚本、库文件、示例配置和文档 | 项目结构 |
| `tests/test_session_state.sh` | 验证 session state 路径、初始化、alias 设置/清理/自动生成、latest action TTL、`CLAUDE_HARK_HOME` 覆盖 | 状态模块 |
| `tests/test_action_summary.sh` | 验证 hook payload 解析、tool target 提取、fallback summary、外部 summarizer、脱敏、递归保护和摘要长度限制 | 摘要模块 |
| `tests/test_notifier.sh` | 验证 `notify_user` 在 stub 模式下写入通知标题和内容 | 通知统一入口 |
| `tests/test_notify_macos.sh` | 验证 `notify_macos` 在 stub 模式下写入通知标题和内容 | macOS 通知实现 |
| `tests/test_hook_flow.sh` | 验证主 hook 的 `pre-tool-use`、`permission`、`elicitation` 端到端流程 | 主集成流程 |
| `tests/test_cli.sh` | 验证 CLI alias set/get/clear 和 doctor 输出 | CLI |
| `tests/test_install.sh` | 验证安装脚本复制可执行文件并写入 Claude Code hooks 配置 | 安装流程 |

## 当前测试目的

整体测试目标是分层的：

1. **结构完整性**：`test_layout.sh` 确保仓库包含发布所需文件。
2. **核心纯逻辑/状态模块**：`test_session_state.sh` 和 `test_action_summary.sh` 覆盖大多数业务规则。
3. **通知适配层**：`test_notifier.sh` 和 `test_notify_macos.sh` 验证通知写入接口。
4. **端到端 hook 流程**：`test_hook_flow.sh` 验证 payload 进入 hook 后，状态更新、摘要复用、通知发送和 `systemMessage` 输出是否一致。
5. **CLI 与交付**：`test_cli.sh`、`test_install.sh` 分别覆盖命令行和安装产物。

这个分层基本清晰：模块测试负责规则细节，hook 流程测试负责串联行为，安装/布局测试负责交付完整性。

## 可能冗余的测试

### 1. `test_notifier.sh` 与 `test_notify_macos.sh` 的 stub 断言高度重复

两个测试都只验证 `CLAUDE_HARK_NOTIFY_STUB` 存在时，函数会把 `title|body` 写入同一个文件格式：

- `test_notifier.sh` 调用 `notify_user`。
- `test_notify_macos.sh` 调用 `notify_macos`。

它们并非完全等价，因为 `notify_user` 是跨平台统一入口，`notify_macos` 是 macOS 实现。但当前断言只覆盖了二者共同的 stub 分支，没有覆盖 `notify_user` 的系统分派逻辑，也没有覆盖 `notify_macos` 的 `osascript` 转义行为。

建议保留二者，但调整目的：

- `test_notify_macos.sh` 继续作为 macOS adapter 的 stub smoke test。
- `test_notifier.sh` 最好补充或改成验证 `notify_user` 在 Darwin/Linux/unknown 下选择不同后端；否则它和 `test_notify_macos.sh` 的有效覆盖重叠较大。

### 2. `test_action_summary.sh` 与 `test_hook_flow.sh` 对 fallback 文案有重复覆盖

`test_action_summary.sh` 已直接验证：

- `Edit` → `准备修改 README.md 以完成当前步骤`
- `Write` → `准备写入 config.json 以完成当前步骤`
- `Bash` test command → `运行验证命令确认当前结果`
- `elicitation` → `等待你做选择以继续当前任务`

`test_hook_flow.sh` 又通过主 hook 间接断言 `Write` fallback 和 `elicitation` fallback 文案。

这些重复有一定价值，因为集成测试需要确认最终通知内容。但风险是文案变更时会导致多个测试一起失败，维护成本偏高。

建议：

- 模块测试继续精确断言全部 fallback 文案。
- 集成测试只精确断言关键拼接结构和状态复用，例如包含 `等待权限：Write`、包含 alias、包含目的字段；除非该文案本身就是端到端契约。

### 3. `test_layout.sh` 与 `test_install.sh` 对交付文件有轻微重复

`test_layout.sh` 验证源仓库中存在 `hooks/claude-hark.sh`、`bin/claude-hark` 等路径。

`test_install.sh` 验证这些文件被复制到安装目录并可执行。

这不是严重冗余：前者是源码布局，后者是安装结果。但如果维护成本增加，可以考虑让 `test_install.sh` 成为更强的交付测试，并减少 `test_layout.sh` 对脚本路径的重复检查，只保留文档/示例/关键入口存在性。

## 测试目的不一致或不够清晰的地方

### 1. `test_notify_macos.sh` 的名称暗示 macOS 行为，但实际只测试 stub 分支

该测试没有验证 `osascript` 命令、字符串转义或 Darwin 环境行为，只验证 stub 写文件。因此测试名和实际目的略有偏差。

可选处理：

- 保持文件名，但在测试中增加对引号转义/`osascript` 调用的可测试 seam。
- 或将目的视为 adapter smoke test，在文档或测试注释中明确它只覆盖 stub 模式。

### 2. `test_notifier.sh` 的名称暗示通知路由，但实际没有覆盖路由

`notify_user` 的主要职责包括：

- stub 模式下写文件；
- Darwin 下调用 `notify_macos`；
- Linux 下优先 `notify-send`；
- 其他系统或缺少命令时写 stderr fallback。

当前测试只覆盖第一项。若测试名保持为 `test_notifier.sh`，建议补充路由行为；否则它更像 `notify_user` stub 写入测试。

### 3. `test_install.sh` 对 settings 的断言偏字符串级

`test_install.sh` 通过 `assert_contains` 检查 settings 内容中包含 `PreToolUse`、`PermissionRequest`、`Elicitation`、matcher 和脚本名。

这能覆盖基本安装结果，但目的如果是“安装脚本写入正确 Claude Code hooks 配置”，字符串包含断言不够精确：例如 hook 结构层级错误、timeout 错误或 command 对应事件错误时，仍可能通过。

建议改成用 `jq` 验证 JSON 结构中的具体字段：

- `hooks.PreToolUse[0].matcher == "Edit|Write|Bash"`
- `hooks.PermissionRequest[0].matcher == "Edit|Write|Bash|mcp__.*"`
- `hooks.Elicitation[0].hooks[0].command` 指向 `claude-hark.sh elicitation`
- timeout 为 `5`

### 4. `test_cli.sh` 的 doctor 测试依赖宿主环境

`test_cli.sh` 断言 `doctor` 输出包含 `osascript: ok`。这与当前项目主要目标一致，但会让测试在非 macOS 环境下失败。

如果项目只支持 macOS，这个断言是合理的；如果 README 或安装目标包含 Linux fallback，则该测试目的应改为按平台断言：Darwin 检查 `osascript`，Linux 检查 `notify-send` 输出。

### 5. `test_session_state.sh` 覆盖较多职责，失败定位可能不够集中

该文件同时覆盖路径、初始化、alias、自动 alias、latest action TTL、home override。它们都属于 session state 模块，目的并不冲突，但单个脚本较“宽”。

如果后续继续扩展 state 逻辑，建议拆分为：

- state path/init；
- alias resolution；
- latest action TTL。

当前规模下不必强制拆分。

## 覆盖缺口

现有测试没有明显无意义测试，但有一些重要行为尚未覆盖：

1. `notify_macos` 的 `osascript` 分支和引号转义。
2. `notify_user` 的 Darwin/Linux/unknown 路由。
3. `install.sh` 对既有 settings 的保留/覆盖策略。
4. `hooks/claude-hark.sh` 对 unsupported event kind 的错误行为。
5. `action_summary.py` 对 MCP tool 或未知 tool 的 fallback 行为，尤其 `PermissionRequest` matcher 包含 `mcp__.*`。
6. `session-state.sh` 在空 `cwd`、空 `session_id` 或异常 JSON 状态文件下的行为；如果这些不是支持场景，可以不补。

## 建议优先级

1. **优先调整 `test_install.sh`**：从字符串包含升级为 JSON 结构断言，能显著提升测试目的和断言一致性。
2. **明确通知层测试边界**：决定 `test_notifier.sh` 是否要覆盖平台路由；如果不覆盖，可接受它和 `test_notify_macos.sh` 的轻微重复。
3. **降低集成测试对 fallback 文案的重复耦合**：让 `test_action_summary.sh` 负责文案细节，hook flow 负责状态复用和消息结构。
4. **根据支持平台调整 `test_cli.sh`**：如果要支持 Linux，就避免固定断言 `osascript: ok`。
5. **暂不拆分 `test_session_state.sh`**：它目前职责集中在同一模块内，冗余不严重。

## 结论

当前测试套件整体目标一致，没有明显“测错方向”的文件。主要问题是通知相关测试的覆盖边界不够清晰，以及部分集成测试重复锁定了模块测试已经覆盖的 fallback 文案。建议优先提升安装配置断言的结构化程度，并明确 `notifier`/`notify_macos` 两层测试各自要证明的行为。