#! /usr/bin/env bash
# ============================================================
# CRON INSTALLER — Auto-scan scheduler
# Usage: ./setup-cron.sh
# ============================================================
set -euo pipefail
BB_HOME="${BB_HOME:-$HOME/bug-bounty}"
TARGETS="$BB_HOME/targets/targets.txt"
[ ! -f "$TARGETS" ] && touch "$TARGETS"

echo "🔄 Installing cron jobs..."
(crontab -l 2>/dev/null | grep -v "recon.sh\|nuclei-update"; \
 echo "# === BB PIPELINE ==="; \
 echo "*/30 * * * * cd $BB_HOME && bash scripts/recon.sh quick \$(head -1 $TARGETS) 2>/dev/null"; \
 echo "0 */4 * * * cd $BB_HOME && bash scripts/recon.sh quick \$(sed -n '2p' $TARGETS) 2>/dev/null"; \
 echo "0 6 * * * cd $BB_HOME && bash scripts/recon.sh nuclei-update 2>/dev/null"; \
 echo "0 7 * * * cd $BB_HOME && cat $TARGETS | while read d; do bash scripts/recon.sh quick \$d 2>/dev/null; done"; \
) | crontab -
echo "✅ Cron installed:"
crontab -l | grep -v "^#"