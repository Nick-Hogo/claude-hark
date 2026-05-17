# External LLM command adapter with timeout, recursion guard, and redaction helpers.
import json
import os
import re
import subprocess

from util import first_nonempty_line, load_json, redact_sensitive_text, summary_max_chars, truncate_text


class LLMSummaryProvider:
    DEFAULT_SUMMARY_MAX_CHARS = 80
    DEFAULT_SUMMARIZER_TIMEOUT = 3
    PROMPT_INPUT_MODE = "prompt"
    PAYLOAD_INPUT_MODE = "payload"

    def __init__(self, env=None):
        self.env = env or os.environ

    def source(self):
        if not self.available():
            return "fallback"
        return "external" if self.input_mode() == self.PAYLOAD_INPUT_MODE else "llm"

    def available(self):
        has_summarizer = bool(self.env.get("CLAUDE_HARK_SUMMARIZER_COMMAND"))
        is_summarizing = self.env.get("CLAUDE_HARK_SUMMARIZING") == "1"
        return has_summarizer and not is_summarizing

    def input_mode(self):
        mode = self.env.get("CLAUDE_HARK_SUMMARIZER_INPUT_MODE", self.PROMPT_INPUT_MODE).strip().lower()
        return mode if mode in (self.PROMPT_INPUT_MODE, self.PAYLOAD_INPUT_MODE) else self.PROMPT_INPUT_MODE

    @staticmethod
    def sanitize_payload(event_kind, tool_name, tool_input_json):
        data = load_json(tool_input_json, {})
        if not isinstance(data, dict):
            data = {}

        if tool_name == "Edit":
            sanitized = {
                "file_path": data.get("file_path", ""),
                "old_string": data.get("old_string", ""),
                "new_string": data.get("new_string", ""),
            }
        elif tool_name == "Write":
            sanitized = {
                "file_path": data.get("file_path", ""),
                "content": data.get("content", ""),
            }
        elif tool_name == "Bash":
            sanitized = {"command": data.get("command", "")}
        else:
            sanitized = {"tool_input": data}

        serialized = json.dumps(sanitized, ensure_ascii=False, indent=2)
        return redact_sensitive_text(truncate_text(serialized, 1200))

    @staticmethod
    def normalize(raw):
        summary = first_nonempty_line(raw)
        summary = re.sub(r"^[\-*>#\d\.、\s]+", "", summary)
        summary = summary.strip(" `\t\r\n")
        summary = re.sub(r"^(?:修改)?目的[：:]\s*", "", summary)
        return summary[: summary_max_chars()]

    def run(self, prompt_or_payload):
        # The guard prevents hook-triggered LLM calls from recursively invoking this hook path.
        command = self.env["CLAUDE_HARK_SUMMARIZER_COMMAND"]
        timeout = float(self.env.get("CLAUDE_HARK_SUMMARIZER_TIMEOUT", str(self.DEFAULT_SUMMARIZER_TIMEOUT)))
        child_env = self.env.copy()
        child_env["CLAUDE_HARK_SUMMARIZING"] = "1"
        try:
            result = subprocess.run(
                command,
                input=prompt_or_payload,
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
