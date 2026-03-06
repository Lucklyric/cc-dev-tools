#!/bin/bash
# Telegram notification script for Claude Code hooks
# Usage: notify.sh <MSG_VAR_NAME> <DEFAULT_MESSAGE>

MSG_VAR="$1"
DEFAULT_MSG="$2"

TAG="[$(hostname -s):${CLAUDE_PROJECT_DIR##*/}]"

if [[ -z "$CC_TELEGRAM_BOT_TOKEN" || -z "$CC_TELEGRAM_CHAT_ID" ]]; then
  echo "Telegram notification skipped: Set CC_TELEGRAM_BOT_TOKEN and CC_TELEGRAM_CHAT_ID"
  exit 0
fi

MESSAGE="$TAG ${!MSG_VAR:-$DEFAULT_MSG}"

if [[ "${CC_TELEGRAM_DRY_RUN:-false}" == "true" ]]; then
  echo "[DRY RUN] $MESSAGE"
  exit 0
fi

curl -s -X POST "https://api.telegram.org/bot$CC_TELEGRAM_BOT_TOKEN/sendMessage" \
  -d "chat_id=$CC_TELEGRAM_CHAT_ID" \
  -d "text=$MESSAGE" \
  -d "parse_mode=HTML" >/dev/null 2>&1 || echo "Failed to send Telegram notification"
