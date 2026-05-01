# Hooks
> 当 AI Agent 从“辅助生成内容”走向“实际执行操作”时，能力不再是边界，边界本身才是新的能力；Hook —— 将 Agent 行动权重新拉回工程控制之内的“钩子”。

作为重度Vibe Coding使用者，在使用AI的过程中，在项目不断的Vibe Coding迭代的的过程中的时常出现失控感，特别是在程序长时间执行过程中：由于中间思考决策过程的缺失，导致一旦程序申请权限或者确认是否同意更改文件等等风险操作时都需要花大量时间来进行double check。

为了加深自己对Agent的理解，同时也在开发插件使得在使用类Claude Code Cli的过程中让开发者中重新获得掌控感，对claude code的hook机制仔细研读，顺便以写教程的方式促进自己的理解,以下是对官方文档的理解，如有兴趣可自行查看![官方文档](https://code.claude.com/docs/zh-CN/hooks)

## 前言
Agent的概念层出不穷，在正式介绍Hook之前，也许你在意的是他跟目前广为人知的MCP，Skill之间的差异，为什么我们会需要Hook而不是其他的？这一点很重要，因为在知识获取门槛极大降低的同时，明白各个技术的边界将成为你使用工具还是工具使用你最重要的区别：

| 机制        | 核心问题                       | 更像什么            |
| --------- | -------------------------- | --------------- |
| **Skill** | Claude 应该如何完成某类任务？         | 任务说明书 / 工作流知识包  |
| **MCP**   | Claude 可以调用哪些外部能力？         | 工具接口 / 外部能力总线   |
| **Hook**  | Claude 执行到某个节点时，必须先经过什么规则？ | 生命周期拦截器 / 工程治理层 |

总而言之，Hook 像是加在 Agent 执行链路上的一把“工程锁”：它不是为了限制 Agent 的能力，而是为了让 Agent 的每一次关键行动都能被看见、被解释、被约束、被接管。在几乎不牺牲执行灵活性的前提下，Hook 极大增强了工程师对 Agent 行为边界的掌控。

## 什么是Hook？

hook的英文直译就是钩子，如果你之前没接触过事件响应、插件或者复杂框架，第一次看到这个词可能会有点懵：程序里的钩子是什么的？其实可以把 Hook 就是一种 **“在特定时机自动执行的函数”** 。比如说，某个事件发生了、某个流程结束了、某个状态发生变化了，系统就会自动调用你提前写好的那段代码。就像你提前在这个位置“挂了一个钩子”，等程序运行到这里时，这个钩子就会被 **连带** 触发。作为一种抽象概念hook的思想广泛存在不同领域/场景，例如： 

> - 前端组件挂载后执行初始化逻辑；
> - Git 提交前自动运行格式检查；
> - 请求完成后执行回调处理；
> - 程序退出前自动保存状态或清理资源。

在claude code中也用于有效管理Agent的运行设计了对应的hook机制，并且贯穿整个 **Agent生命周期** 

与详细的官方文档不同，这篇博文将从下面三个问题出发让你快速理解Hook的整个逻辑，当你需要使用Hook来改善你自己的工作流的时候能快速切入：
When？ —— Hook的触发时机（Trigger）
What？ —— Hook的匹配机制（Matcher）
How？ —— Hook的执行逻辑（Action）

## Hook的触发时机（Trigger）

Claude Code 处理一次用户请求时，并不是简单地“接收输入，然后生成答案”。它会进入一轮完整的 Agent 执行流程：接收用户输入、理解任务意图、规划操作、调用工具、处理工具结果，并根据结果继续迭代，直到任务完成或中止。这个流程对应的就是Agent的生命周期，在生命周期的各个阶段都可以使用hook来执行对应的逻辑，下面是官方以流程图的形式可视化了这个过程：  


从 Agent 运行设计的角度，笔者将hook的触发时机大致的归类为四类分别对应Agent四项基础能力：

1. **输入与提示词工程（Prompt Engineering）**：负责会话初始化、上下文注入、用户输入检查和 Prompt 展开，决定用户请求如何进入 Agent 流程。
2. **工具调用控制（Tool Use）**：负责工具调用前后的权限校验、安全拦截、结果处理和失败处理，决定 Agent 如何安全地执行外部操作。
3. **事务分发与子代理编排（Sub-agent / Task Orchestration）**：负责复杂任务的拆分、分发、子代理启动和任务完成追踪，决定 Agent 如何组织多步骤任务。
4. **上下文与状态管理（Context Management）**：负责上下文压缩、配置变化、文件变化和通知事件，决定 Agent 如何维护运行状态和长期上下文。

目前可设置的触发时机有29个，以输入与提示词工程为例：`SessionStart`、`SessionEnd`分别在创建会话以及结束会话时可以调用，适合注入系统提示词/持久化会话内容的功能，`UserPromptSubmit`、`UserPromptExpansion`用于优化或者二次处理用户提示。笔者根据自己的理解对目前的29个触发时机进行分类，方便后续查找以及理解

<details open>
<summary>点击收起</summary>
Trigger 分类
<table>
  <thead>
    <tr>
      <th>分类</th>
      <th>Event</th>
      <th>触发时机</th>
      <th>作用理解</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="5"><strong>输入与指令注入层</strong><br/>Input & Instruction Injection</td>
      <td><code>Setup</code></td>
      <td>使用 <code>--init-only</code>，或在 <code>-p</code> 模式下使用 <code>--init</code> / <code>--maintenance</code> 启动时触发</td>
      <td>用于 CI、脚本或一次性初始化准备</td>
    </tr>
    <tr>
      <td><code>SessionStart</code></td>
      <td>会话开始或恢复时触发</td>
      <td>用于会话初始化、环境检查、上下文注入</td>
    </tr>
    <tr>
      <td><code>UserPromptSubmit</code></td>
      <td>用户提交 prompt 后、Claude 处理之前触发</td>
      <td>用于输入检查、prompt 预处理、上下文补充</td>
    </tr>
    <tr>
      <td><code>UserPromptExpansion</code></td>
      <td>用户输入的命令被展开为 prompt、送入 Claude 之前触发，可阻止展开</td>
      <td>用于 slash command 展开控制、prompt 改写或拦截</td>
    </tr>
    <tr>
      <td><code>InstructionsLoaded</code></td>
      <td><code>CLAUDE.md</code> 或 <code>.claude/rules/*.md</code> 被加载进上下文时触发</td>
      <td>用于项目规则、系统指令和上下文约束的注入</td>
    </tr>
    <tr>
      <td rowspan="8"><strong>工具执行控制层</strong><br/>Tool Execution Control</td>
      <td><code>PreToolUse</code></td>
      <td>工具调用执行前触发，可阻止执行</td>
      <td>用于权限校验、危险操作拦截、参数检查</td>
    </tr>
    <tr>
      <td><code>PermissionRequest</code></td>
      <td>出现权限确认弹窗时触发</td>
      <td>用于记录或处理需要用户授权的工具操作</td>
    </tr>
    <tr>
      <td><code>PermissionDenied</code></td>
      <td>工具调用被自动模式分类器拒绝时触发，可返回 <code>{retry: true}</code> 允许模型重试</td>
      <td>用于处理被拒绝的工具调用和重试逻辑</td>
    </tr>
    <tr>
      <td><code>PostToolUse</code></td>
      <td>工具调用成功后触发</td>
      <td>用于结果记录、自动格式化、后处理</td>
    </tr>
    <tr>
      <td><code>PostToolUseFailure</code></td>
      <td>工具调用失败后触发</td>
      <td>用于失败分析、错误日志、修复提示</td>
    </tr>
    <tr>
      <td><code>PostToolBatch</code></td>
      <td>一整批并行工具调用完成后、下一次模型调用前触发</td>
      <td>用于批量结果汇总、统一审计和状态更新</td>
    </tr>
    <tr>
      <td><code>Elicitation</code></td>
      <td>MCP server 在工具调用过程中请求用户输入时触发</td>
      <td>用于处理工具执行过程中的额外确认或补充信息请求</td>
    </tr>
    <tr>
      <td><code>ElicitationResult</code></td>
      <td>用户响应 MCP elicitation 后、结果发送回 server 前触发</td>
      <td>用于检查、改写或记录用户补充输入</td>
    </tr>
    <tr>
      <td rowspan="5"><strong>任务编排层</strong><br/>Task & Sub-agent Orchestration</td>
      <td><code>SubagentStart</code></td>
      <td>子代理被启动时触发</td>
      <td>用于记录子任务启动、初始化子代理环境</td>
    </tr>
    <tr>
      <td><code>SubagentStop</code></td>
      <td>子代理完成时触发</td>
      <td>用于收集子代理结果、清理子任务状态</td>
    </tr>
    <tr>
      <td><code>TaskCreated</code></td>
      <td>通过 <code>TaskCreate</code> 创建任务时触发</td>
      <td>用于任务分发、任务追踪和调度记录</td>
    </tr>
    <tr>
      <td><code>TaskCompleted</code></td>
      <td>任务被标记为完成时触发</td>
      <td>用于任务完成记录、结果回收和状态同步</td>
    </tr>
    <tr>
      <td><code>TeammateIdle</code></td>
      <td>agent team 中的 teammate 即将进入 idle 状态时触发</td>
      <td>用于团队式 agent 协作中的空闲状态管理</td>
    </tr>
    <tr>
      <td rowspan="11"><strong>上下文与运行状态层</strong><br/>Context & Runtime State</td>
      <td><code>Notification</code></td>
      <td>Claude Code 发送通知时触发</td>
      <td>用于通知转发、消息记录或外部提醒</td>
    </tr>
    <tr>
      <td><code>ConfigChange</code></td>
      <td>会话期间配置文件发生变化时触发</td>
      <td>用于动态更新配置、刷新运行环境</td>
    </tr>
    <tr>
      <td><code>CwdChanged</code></td>
      <td>工作目录发生变化时触发，例如 Claude 执行 <code>cd</code> 命令</td>
      <td>用于响应式环境管理，如联动 <code>direnv</code></td>
    </tr>
    <tr>
      <td><code>FileChanged</code></td>
      <td>被监听的文件发生变化时触发，<code>matcher</code> 指定监听文件</td>
      <td>用于文件变更感知、自动重载或触发检查</td>
    </tr>
    <tr>
      <td><code>WorktreeCreate</code></td>
      <td>通过 <code>--worktree</code> 或 <code>isolation: "worktree"</code> 创建 worktree 时触发</td>
      <td>用于替换默认 git 行为、隔离工作区初始化</td>
    </tr>
    <tr>
      <td><code>WorktreeRemove</code></td>
      <td>会话退出或子代理完成后移除 worktree 时触发</td>
      <td>用于清理隔离工作区和临时资源</td>
    </tr>
    <tr>
      <td><code>PreCompact</code></td>
      <td>上下文压缩前触发</td>
      <td>用于压缩前保存关键信息、整理上下文</td>
    </tr>
    <tr>
      <td><code>PostCompact</code></td>
      <td>上下文压缩完成后触发</td>
      <td>用于检查压缩结果、恢复必要状态</td>
    </tr>
    <tr>
      <td><code>Stop</code></td>
      <td>Claude 完成响应时触发</td>
      <td>用于单轮响应结束后的收尾处理</td>
    </tr>
    <tr>
      <td><code>StopFailure</code></td>
      <td>因 API 错误导致当前 turn 结束时触发，输出和退出码会被忽略</td>
      <td>用于记录异常结束、错误追踪</td>
    </tr>
    <tr>
      <td><code>SessionEnd</code></td>
      <td>会话终止时触发</td>
      <td>用于最终日志记录、资源释放和会话清理</td>
    </tr>
  </tbody>
</table>
</detail>

## Hook的匹配器（Matcher）
在确定 Hook 的触发时机（Trigger）之后，并不意味着该触发节点下的所有 Hook 都会被执行。Claude Code 还会继续根据 `matcher` 做一次过滤：只有当前事件满足匹配条件时，对应 Hook 才会被执行。

对于 `PreToolUse` / `PostToolUse` 这类工具事件 `matcher` 匹配的是本次调用的具体工具名，而在`SessionStart`中匹配的是会话启动方式，`Setup` 匹配的是触发 setup 的 CLI flag。 具体的触发时机启用的匹配字段需要查看![官方文档](https://code.claude.com/docs/zh-CN/hooks)来确认，官方文档中对每个触发时机的参数都有详细的说明，下面为了方便查找，按照之前的分类进行简单的展示来方便快速查找：

<details open>
<summary>Matcher 匹配对象速查表</summary>
<table>
  <thead>
    <tr>
      <th>分类</th>
      <th>Event</th>
      <th>matcher 检查对象</th>
      <th>示例 matcher</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td rowspan="5"><strong>输入与指令注入层</strong><br/>Input & Instruction Injection</td>
      <td><code>Setup</code></td>
      <td>检查触发 setup 的 CLI flag</td>
      <td><code>init</code>、<code>maintenance</code></td>
    </tr>
    <tr>
      <td><code>SessionStart</code></td>
      <td>检查会话启动方式</td>
      <td><code>startup</code>、<code>resume</code>、<code>clear</code>、<code>compact</code></td>
    </tr>
    <tr>
      <td><code>UserPromptSubmit</code></td>
      <td>不做二次检查，用户提交 prompt 时直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td><code>UserPromptExpansion</code></td>
      <td>检查被展开的用户命令名称</td>
      <td>slash command 或 skill command 名称</td>
    </tr>
    <tr>
      <td><code>InstructionsLoaded</code></td>
      <td>检查指令加载原因</td>
      <td><code>session_start</code>、<code>nested_traversal</code>、<code>path_glob_match</code>、<code>include</code>、<code>compact</code></td>
    </tr>
    <tr>
      <td rowspan="8"><strong>工具执行控制层</strong><br/>Tool Execution Control</td>
      <td><code>PreToolUse</code></td>
      <td>检查本次即将调用的工具名，即 <code>tool_name</code></td>
      <td><code>Bash</code>、<code>Edit|Write</code>、<code>mcp__.*</code></td>
    </tr>
    <tr>
      <td><code>PermissionRequest</code></td>
      <td>检查本次申请权限的工具名，即 <code>tool_name</code></td>
      <td><code>Bash</code>、<code>Edit|Write</code>、<code>mcp__.*</code></td>
    </tr>
    <tr>
      <td><code>PermissionDenied</code></td>
      <td>检查本次被拒绝的工具名，即 <code>tool_name</code></td>
      <td><code>Bash</code>、<code>Edit|Write</code>、<code>mcp__.*</code></td>
    </tr>
    <tr>
      <td><code>PostToolUse</code></td>
      <td>检查本次成功执行的工具名，即 <code>tool_name</code></td>
      <td><code>Bash</code>、<code>Edit|Write</code>、<code>mcp__.*</code></td>
    </tr>
    <tr>
      <td><code>PostToolUseFailure</code></td>
      <td>检查本次执行失败的工具名，即 <code>tool_name</code></td>
      <td><code>Bash</code>、<code>Edit|Write</code>、<code>mcp__.*</code></td>
    </tr>
    <tr>
      <td><code>PostToolBatch</code></td>
      <td>不做二次检查，一批并行工具调用完成后直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td><code>Elicitation</code></td>
      <td>检查发起用户输入请求的 MCP server 名称</td>
      <td>对应 MCP server 名称</td>
    </tr>
    <tr>
      <td><code>ElicitationResult</code></td>
      <td>检查接收用户输入结果的 MCP server 名称</td>
      <td>对应 MCP server 名称</td>
    </tr>
    <tr>
      <td rowspan="5"><strong>任务编排层</strong><br/>Task & Sub-agent Orchestration</td>
      <td><code>SubagentStart</code></td>
      <td>检查被启动的 agent 类型或自定义 agent 名称</td>
      <td><code>general-purpose</code>、<code>Explore</code>、<code>Plan</code> 或自定义名称</td>
    </tr>
    <tr>
      <td><code>SubagentStop</code></td>
      <td>检查结束运行的 agent 类型或自定义 agent 名称</td>
      <td><code>general-purpose</code>、<code>Explore</code>、<code>Plan</code> 或自定义名称</td>
    </tr>
    <tr>
      <td><code>TaskCreated</code></td>
      <td>不做二次检查，任务创建时直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td><code>TaskCompleted</code></td>
      <td>不做二次检查，任务完成时直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td><code>TeammateIdle</code></td>
      <td>不做二次检查，teammate 即将 idle 时直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td rowspan="11"><strong>上下文与运行状态层</strong><br/>Context & Runtime State</td>
      <td><code>Notification</code></td>
      <td>检查通知类型</td>
      <td><code>permission_prompt</code>、<code>idle_prompt</code>、<code>auth_success</code>、<code>elicitation_dialog</code>、<code>elicitation_complete</code>、<code>elicitation_response</code></td>
    </tr>
    <tr>
      <td><code>ConfigChange</code></td>
      <td>检查发生变化的配置来源</td>
      <td><code>user_settings</code>、<code>project_settings</code>、<code>local_settings</code>、<code>policy_settings</code>、<code>skills</code></td>
    </tr>
    <tr>
      <td><code>CwdChanged</code></td>
      <td>不做二次检查，工作目录变化时直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td><code>FileChanged</code></td>
      <td>检查需要监听的文本文件名；该事件较特殊，matcher 用于建立监听列表</td>
      <td><code>.envrc|.env</code>、<code>CLAUDE.md</code></td>
    </tr>
    <tr>
      <td><code>WorktreeCreate</code></td>
      <td>不做二次检查，worktree 创建时直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td><code>WorktreeRemove</code></td>
      <td>不做二次检查，worktree 移除时直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td><code>PreCompact</code></td>
      <td>检查触发上下文压缩的原因</td>
      <td><code>manual</code>、<code>auto</code></td>
    </tr>
    <tr>
      <td><code>PostCompact</code></td>
      <td>检查触发上下文压缩的原因</td>
      <td><code>manual</code>、<code>auto</code></td>
    </tr>
    <tr>
      <td><code>Stop</code></td>
      <td>不做二次检查，Claude 完成响应时直接触发</td>
      <td>无需配置</td>
    </tr>
    <tr>
      <td><code>StopFailure</code></td>
      <td>检查导致当前 turn 结束的错误类型</td>
      <td><code>rate_limit</code>、<code>authentication_failed</code>、<code>billing_error</code>、<code>invalid_request</code>、<code>server_error</code>、<code>max_output_tokens</code>、<code>unknown</code></td>
    </tr>
    <tr>
      <td><code>SessionEnd</code></td>
      <td>检查会话结束原因</td>
      <td><code>clear</code>、<code>resume</code>、<code>logout</code>、<code>prompt_input_exit</code>、<code>bypass_permissions_disabled</code>、<code>other</code></td>
    </tr>
  </tbody>
</table>
</details>

由于单个hook包含多种触发条件，因此可以使用正则匹配的方式来自己组合可能的触发情况，具体的操作可以参考官方给出的方式：
| 写法              | 含义         | 示例                              |                   |         |
| --------------- | ---------- | ------------------------------- | ----------------- | ------- |
| 省略 / 空字符串 / `*` | 匹配全部       | `"matcher": "*"`                |                   |         |
| 精确匹配            | 只匹配指定对象    | `"matcher": "Bash"`             |                   |         |
| 多值匹配            | 用 `        | ` 匹配多个对象                        | `"matcher": "Edit | Write"` |
| 正则匹配            | 匹配更复杂的名称模式 | `"matcher": "mcp__.*__write.*"` |                   |         |


## Hook的执行器（Handler）
在恰当的触发节点，对应的Hook满足了匹配器的触发条件，那么就可以触发后续的执行逻辑，也就是实际的可执行的具体操作，为了保证可扩展性，同时为了维持对MCP，Http，Command的不同响应差异，Claude Code对Hook将执行的操作使用字段来进行区分来适配不同方式独特的需求，官方目前支持了5种不同的类型：

| Handler 类型     | 配置写法               | 执行方式                                             | 适合场景                             |
| -------------- | ------------------ | ------------------------------------------------ | -------------------------------- |
| 命令型     | `type: "command"`  | 执行本地 shell 命令或脚本                                 | 日志记录、格式化、lint、安全检查、权限拦截          |
| HTTP    | `type: "http"`     | 将 Hook 输入 JSON 作为 HTTP POST 请求发送到指定 URL          | 接入远程审计服务、团队策略服务、Webhook 系统       |
| MCP 工具  | `type: "mcp_tool"` | 调用已连接 MCP server 上的工具                            | 复用现有 MCP 能力，例如安全扫描、知识库查询、业务系统校验  |
| Prompt  | `type: "prompt"`   | 向 Claude 模型发送一次提示，进行单轮判断                         | 让模型解释权限原因、判断操作风险、生成轻量决策          |
| Agent   | `type: "agent"`    | 启动一个 subagent，并允许其使用 Read、Grep、Glob 等工具验证条件后返回结果 | 更复杂的检查任务，例如跨文件审查、代码变更复核；官方标注为实验性 |

总的来说，根据实际需求你可以进行下面的判断：

- 如果需要接入外部服务，用 `http`；
- 如果已有 MCP 工具可复用，用 `mcp_tool`；
- 如果需要模型做一次轻量判断，用 `prompt`；
- 如果需要一个能读文件、查代码、综合判断的子代理，用 `agent`。

## 实例解析（MVP）
在了解了Hook的触发时机（Trigger），匹配机制（Matcher）以及 执行器（Handler）的抽象逻辑之后，笔者介绍一个具体的例子，来介绍时机Claude Code中是如何将上面讲的抽象概念转为可拓展开发的工程实践。只要读懂这个实例那么就掌握了绝大部分hook的知识。

与 MCP、Skill 类似，Claude Code 也通过配置文件来管理 Hook。Hook 通常写在 `settings.json` 中，并可以根据配置文件所在位置作用于不同范围（用户级/项目级）。

<detail>
<summary> 点击展开示例配置<\summary>
```bash
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Claude is about to use Bash' >> ~/claude-hook-demo.log"
          }
        ]
      }
    ]
  }
}
```
</detail>

下面我们根据之前的总结将 回答三个问题 When？ What？ How？，这三个问题分别对应上述配置的三个字段

| 抽象层                    | 直观问题         | 对应配置                          | 含义                 |
| ---------------------- | ------------ | ----------------------------- | ------------------ |
| Trigger | When：什么时候触发？ | `PreToolUse`                  | 在工具调用执行前触发         |
| Matcher | What：匹配什么对象？ | `"Bash"`                      | 只匹配 Bash 工具调用      |
| Handler | How：命中后如何执行？ | `type: "command"` + `command` | 匹配成功后执行一条 shell 命令 |


>+ 第一，`PreToolUse` 决定 Hook 挂在哪个生命周期节点。它表示“工具调用前”，所以这个 Hook 会发生在 Bash 真正执行之前。
>+ 第二，`matcher: "Bash"` 匹配的不是 `PreToolUse` 这个事件名，而是本次工具调用的工具名称。也就是说，只有当 Claude Code 即将调用的工具是 `Bash` 时，这个 Hook 才会被命中。如果 Claude Code 调用的是 `Read`、`Edit`、`Write` 等其他工具，这条 Hook 不会触发。
>+ 最后，`hooks` 数组中的 `command` 才是真正的执行逻辑。这里的命令只是写入一条日志，因此它不会改变 Claude Code 的执行结果，只是用于观察 Hook 是否被触发。

上面是一个Log型的Hook程序，如果你希望调用Hook的时候执行其他的那么只需要修改command中的内容即可，甚至你可以再调用claude code来进行分析，下面是笔者正在开发的项目的彩蛋～

{
  "hooks": {
    "PermissionRequest": [
      {
        "matcher": "Edit|Write|Bash",
        "hooks": [
          {
            "type": "prompt",
            "prompt": "You are explaining a Claude Code permission request to the user. Based on the hook input, explain in Chinese why Claude is requesting this tool permission. Be concise, concrete, and mention the tool name, target file or command if available. Do not approve or deny the request; only explain the reason."
          }
        ]
      }
    ]
  }
}
</detail>
这个示例展示的是一个“模型解释型 Hook”。

它不是用 `command` 执行固定脚本，而是使用 `prompt` handler，让模型根据本次权限申请的上下文生成说明。这样，当 Claude Code 申请 `Edit`、`Write` 或 `Bash` 权限时，用户不仅能看到“它要申请权限”，还能看到“它为什么需要这个权限”。

例如：

- 如果是 `Edit`，模型可以说明它准备修改哪个文件、修改目的是什么；
- 如果是 `Write`，模型可以说明它准备新建或覆盖哪个文件；
- 如果是 `Bash`，模型可以说明它准备执行什么命令，以及这个命令大致用于什么操作。

需要注意的是，这个 Hook 只负责解释原因，并不代表自动批准或拒绝权限。最终是否允许执行，仍然由权限机制本身决定。

> 这个 Hook 的作用是：在高风险工具申请权限时，用模型动态生成一段面向用户的权限解释。

这个最小可行性Hook就是我目前认为如何在控制多Agent并行开发过程中，迅速切换上下文来当Agent需要授权或者类似操作时，降低开发者理解以及认知负担的原型机（Prototype）

