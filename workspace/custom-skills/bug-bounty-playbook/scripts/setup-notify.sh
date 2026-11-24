#! /usr/bin/env bash
# ============================================================
# SETUP TELEGRAM NOTIFICATION untuk pipeline
# Usage: ./setup-notify.sh <bot_token> <chat_id>
# ============================================================
set -euo pipefail
BOT_TOKEN="${1:-}"
CHAT_ID="${2:-}"
[ -z "$BOT_TOKEN" ] || [ -z "$CHAT_ID" ] && echo "Usage: ./setup-notify.sh <bot_token> <chat_id>" && exit 1

mkdir -p ~/.config/notify
cat > ~/.config/notify/provider-config.yaml << EOF
telegram:
  - id: "bb-alert"
    telegram_api_key: "$BOT_TOKEN"
    telegram_chat_id: "$CHAT_ID"
    telegram_format: "markdown"
EOF
echo "✅ Notify configured!"

echo "Test from BB Pipeline ✅" | notify -provider telegram -id bb-alert -silent \
    && echo "✅ Notification test sent!" || echo "❌ Gagal. Cek token & chat ID."