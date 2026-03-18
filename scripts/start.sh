#!/usr/bin/env bash
# ============================================================
# scripts/start.sh
# Container entrypoint: starts code-server
# ============================================================
set -euo pipefail

# Honor PASSWORD env var (docker-compose injects it)
if [ -n "${PASSWORD:-}" ]; then
  sed -i "s/^# password.*/password: ${PASSWORD}/" \
    /home/developer/.config/code-server/config.yaml 2>/dev/null || true
fi

export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-ap-northeast-1}"
export AWS_REGION="${AWS_REGION:-ap-northeast-1}"
export CLAUDE_CODE_USE_BEDROCK="${CLAUDE_CODE_USE_BEDROCK:-1}"
export ANTHROPIC_MODEL="${ANTHROPIC_MODEL:-jp.anthropic.claude-sonnet-4-6}"

exec code-server \
  --config /home/developer/.config/code-server/config.yaml \
  /home/developer/workspace
