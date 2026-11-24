#! /usr/bin/env bash
# ============================================================
# TAMBAH TARGET BARU ke pipeline + langsung scan
# Usage: ./add-target.sh <domain>
# ============================================================
set -euo pipefail
BB_HOME="${BB_HOME:-$HOME/bug-bounty}"
TARGET="${1:-}"
[ -z "$TARGET" ] && echo "Usage: ./add-target.sh <domain>" && exit 1

echo "$TARGET" >> "$BB_HOME/targets/targets.txt"
sort -u "$BB_HOME/targets/targets.txt" -o "$BB_HOME/targets/targets.txt"
echo "✅ $TARGET ditambahkan ke pipeline!"

# Langsung scan
bash "$BB_HOME/scripts/recon.sh" single "$TARGET"