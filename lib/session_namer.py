# 这个模块负责调用外部命令为 Claude Code 会话生成名称和描述。
# Optional session alias/description generator; manual aliases still win in session-state.sh.
import json
import os
import re
import subprocess

from hook_context import HookContextExtractor
from util import basename, first_nonempty_line, load_json, redact_sensitive_text, truncate_inline, truncate_text


# 封装外部会话命名命令的调用和结果解析。
class SessionNamer:
    DEFAULT_TIMEOUT = 4
    NAMING_ENV = "CLAUDE_HARK_SESSION_NAMING"

    # 保存环境变量来源，便于测试和运行时配置。
    def __init__(self, env=None):
        self.env = env or os.environ

    # 判断外部命令是否已配置且未处于递归保护状态。
    def available(self):
        return bool(self.env.get("CLAUDE_HARK_SESSION_NAMER_COMMAND")) and self.env.get(self.NAMING_ENV) != "1"

    # 构造发送给会话命名器的脱敏上下文。
    def payload(self, cwd, branch, event_kind, tool_name, tool_input_json):
        # Only compact, redacted context is sent to the namer; raw hook payload stays local.
        context = HookContextExtractor.extract(event_kind, tool_name, tool_input_json)
        data = {
            "cwd": cwd,
            "repo_name": basename(cwd),
            "branch": branch,
            "tool_context": {
                "tool_name": context.tool_name,
                "target": context.target,
                "file_name": context.file_name,
                "command_preview": context.command_preview,
                "pattern": context.pattern,
                "path": context.path,
                "query": context.query,
                "contains_redacted": context.contains_redacted,
            },
        }
        return redact_sensitive_text(truncate_text(json.dumps(data, ensure_ascii=False, indent=2), 1600))

    # 执行外部命令并返回其标准输出。
    def run(self, payload):
        if not self.available():
            return None
        timeout = float(self.env.get("CLAUDE_HARK_SESSION_NAMER_TIMEOUT", str(self.DEFAULT_TIMEOUT)))
        child_env = self.env.copy()
        child_env[self.NAMING_ENV] = "1"
        child_env["CLAUDE_HARK_SUMMARIZING"] = "1"
        try:
            result = subprocess.run(
                self.env["CLAUDE_HARK_SESSION_NAMER_COMMAND"],
                input=payload,
                text=True,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.DEVNULL,
                timeout=timeout,
                env=child_env,
                check=False,
            )
        except Exception:
            return None
        return result.stdout if result.returncode == 0 else None

    @staticmethod
    # 清理并截断会话名称。
    def normalize_name(value):
        text = first_nonempty_line(str(value or ""))
        text = re.sub(r"^[\-*>#\d\.、\s]+", "", text).strip(" `\t\r\n")
        return truncate_inline(redact_sensitive_text(text), 48)

    @staticmethod
    # 清理并截断会话描述。
    def normalize_description(value):
        text = " ".join(str(value or "").split())
        return truncate_text(redact_sensitive_text(text), 240)

    @classmethod
    # 解析会话命名器返回的 JSON 结果。
    def parse_output(cls, raw):
        data = load_json(raw or "", {})
        if not isinstance(data, dict):
            return {}
        result = {}
        name = cls.normalize_name(data.get("name", ""))
        description = cls.normalize_description(data.get("description", ""))
        if name:
            result["name"] = name
        if description:
            result["description"] = description
        return result

    # 调用命名器并返回可写入状态的名称和描述。
    def generate(self, cwd, branch, event_kind, tool_name, tool_input_json):
        raw = self.run(self.payload(cwd, branch, event_kind, tool_name, tool_input_json))
        return self.parse_output(raw)
