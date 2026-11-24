#! /usr/bin/env bash
# ============================================================
# AGGRESSIVE BB RECON PIPELINE
# Usage:
#   ./recon.sh single <domain>      — Full scan single target
#   ./recon.sh quick <domain>       — Quick nuclei CVE scan
#   ./recon.sh list <file>          — Batch scan from file
#   ./recon.sh nuclei-update        — Update nuclei templates
# ============================================================
set -euo pipefail

BB_HOME="${BB_HOME:-$HOME/bug-bounty}"
MODE="${1:-}"
TARGET="${2:-}"

usage() {
    echo "Usage:"
    echo "  recon.sh single <domain>"
    echo "  recon.sh quick <domain>"
    echo "  recon.sh list <file>"
    echo "  recon.sh nuclei-update"
    exit 1
}

[ -z "$MODE" ] && usage
[ -z "$TARGET" ] && [ "$MODE" != "nuclei-update" ] && usage

case "$MODE" in
    "single")
        DOMAIN="$TARGET"
        DIR="$BB_HOME/recon/$DOMAIN"
        mkdir -p "$DIR"

        echo "🔍 [1/5] Subfinder + assetfinder..."
        subfinder -d "$DOMAIN" -all -silent | sort -u > "$DIR/subs_raw.txt"
        assetfinder --subs-only "$DOMAIN" 2>/dev/null | sort -u >> "$DIR/subs_raw.txt"
        sort -u "$DIR/subs_raw.txt" -o "$DIR/subs_all.txt"
        echo "   → $(wc -l < "$DIR/subs_all.txt") subdomains"

        echo "🌐 [2/5] httpx live probe..."
        httpx -l "$DIR/subs_all.txt" -silent -status-code -tech-detect -title -o "$DIR/live.txt" 2>/dev/null
        awk '{print $1}' "$DIR/live.txt" > "$DIR/live_urls.txt"
        echo "   → $(wc -l < "$DIR/live_urls.txt") live"

        echo "🔌 [3/5] naabu port scan..."
        naabu -l "$DIR/subs_all.txt" -top-ports 100 -silent -o "$DIR/ports.txt" 2>/dev/null
        echo "   → $(wc -l < "$DIR/ports.txt") open ports"

        echo "⚡ [4/5] nuclei CVE+critical scan..."
        nuclei -l "$DIR/live_urls.txt" \
            -t ~/nuclei-templates/cves/ \
            -t ~/nuclei-templates/misconfiguration/ \
            -t ~/nuclei-templates/vulnerabilities/ \
            -severity critical,high,medium \
            -json -o "$DIR/nuclei_results.json" 2>/dev/null | \
            while IFS= read -r line; do
                echo "$line" | notify -silent 2>/dev/null || true
            done

        echo "📜 [5/5] waybackurls scan..."
        cat "$DIR/live_urls.txt" | waybackurls 2>/dev/null | sort -u > "$DIR/wayback.txt" 2>/dev/null || true
        echo "   → $(wc -l < "$DIR/wayback.txt" 2>/dev/null || echo 0) URLs"

        echo ""
        echo "✅ SCAN COMPLETE: $DOMAIN"
        echo "  Subdomains : $(wc -l < "$DIR/subs_all.txt")"
        echo "  Live       : $(wc -l < "$DIR/live_urls.txt")"
        echo "  Ports      : $(wc -l < "$DIR/ports.txt")"
        echo "  📁 $DIR"

        echo "✅ BB Recon — $DOMAIN | Sub: $(wc -l < "$DIR/subs_all.txt") | Live: $(wc -l < "$DIR/live_urls.txt")" | notify -silent 2>/dev/null || true
        ;;

    "quick")
        DOMAIN="$TARGET"
        echo "⚡ QUICK CVE SCAN: $DOMAIN"
        echo "$DOMAIN" | httpx -silent | nuclei \
            -t ~/nuclei-templates/cves/ \
            -severity critical,high \
            -json -o "$BB_HOME/alerts/quick_$(date +%Y%m%d_%H%M).json" 2>/dev/null | \
            while IFS= read -r line; do
                echo "$line" | notify -silent 2>/dev/null || true
            done
        echo "✅ Quick scan done"
        ;;

    "list")
        FILE="$TARGET"
        [ ! -f "$FILE" ] && echo "❌ File $FILE not found" && exit 1
        echo "📋 Mass scan dari: $FILE"
        while IFS= read -r domain; do
            [ -z "$domain" ] && continue
            $0 single "$domain"
        done < "$FILE"
        ;;

    "nuclei-update")
        echo "🔄 Updating nuclei templates..."
        nuclei -update-templates 2>/dev/null
        echo "✅ Done"
        ;;

    *) usage ;;
esac