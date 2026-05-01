#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
exec bash "$repo_root/hooks/claude-hark.sh" "$@"
