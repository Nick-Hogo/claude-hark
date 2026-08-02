# 这个模块负责调用外部摘要器并规范化 LLM 返回的 hook 分析结果。
# External LLM command adapter with timeout, recursion guard, and redaction helpers.
import os
import re
import subprocess

from util import first_nonempty_line, summary_max_chars


# 封装外部 LLM 摘要器的可用性、输入构造和输出规范化。
class LLMSummaryProvider:
    DEFAULT_SUMMARY_MAX_CHARS = 80
    DEFAULT_SUMMARIZER_TIMEOUT = 3

    # 保存环境变量来源，便于测试和运行时配置。
    def __init__(self, env=None):
        self.env = env or os.environ

    # 返回当前摘要来源标记。
    def source(self):
        return "llm" if self.available() else "fallback"

    # 判断外部命令是否已配置且未处于递归保护状态。
    def available(self):
        has_summarizer = bool(self.env.get("CLAUDE_HARK_SUMMARIZER_COMMAND"))
        is_summarizing = self.env.get("CLAUDE_HARK_SUMMARIZING") == "1"
        return has_summarizer and not is_summarizing

    @staticmethod
    # 将外部摘要器输出规范化为单行摘要。
    def normalize(raw):
        summary = first_nonempty_line(raw)
        summary = re.sub(r"^[\-*>#\d\.、\s]+", "", summary)
        summary = summary.strip(" `\t\r\n")
        summary = re.sub(r"^(?:修改)?目的[：:]\s*", "", summary)
        return summary[: summary_max_chars()]

    # 执行外部命令并返回其标准输出。
    def run(self, prompt):
        # The guard prevents hook-triggered LLM calls from recursively invoking this hook path.
        command = self.env["CLAUDE_HARK_SUMMARIZER_COMMAND"]
        timeout = float(self.env.get("CLAUDE_HARK_SUMMARIZER_TIMEOUT", str(self.DEFAULT_SUMMARIZER_TIMEOUT)))
        child_env = self.env.copy()
        child_env["CLAUDE_HARK_SUMMARIZING"] = "1"
        try:
            result = subprocess.run(
                command,
                input=prompt,
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
