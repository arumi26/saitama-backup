#!/usr/bin/env bash
# fw-recon.sh — static firmware triage (OWASP FSTM stages 3-5).
# Usage: ./fw-recon.sh <firmware.bin>
# Authorized targets only. Read this file before running.
set -u
IMG="${1:-}"
[[ -z "$IMG" || ! -f "$IMG" ]] && { echo "usage: $0 <firmware.bin>"; exit 1; }
IMG="$(realpath "$IMG")"   # absolute — needed because we cd into the workdir later
BASE="$(basename "$IMG")"
WORK="./fw_${BASE}_$(date +%Y%m%d_%H%M%S)"
REPORT="${WORK}/recon.txt"
mkdir -p "$WORK"
sep(){ printf '\n========== %s ==========\n' "$1"; }

{
sep "file type"; file "$IMG"; ls -la "$IMG"; md5sum "$IMG" 2>/dev/null
sep "hexdump header (first 512B)"; hexdump -C -n 512 "$IMG"
} | tee "$REPORT"

sep "entropy (binwalk -E)"
if command -v binwalk >/dev/null; then
  binwalk -E "$IMG" 2>/dev/null | tail -20 | tee -a "$REPORT"
  echo "  -> low/flat = plaintext; high/spiky = encrypted or compressed"
else echo "  [!] binwalk not installed (apt install binwalk / pip install binwalk)"; fi

sep "strings — signatures"
strings -n6 "$IMG" | grep -aoE '(squashfs|jffs2|ubifs|CPIO|uImage|TRX|^hsqs|UBI#)' | sort | uniq -c | head | tee -a "$REPORT"

sep "strings — high-value keywords (creds/keys/urls)"
strings -n6 "$IMG" | grep -aiE 'password|passwd|secret|api[_-]?key|token|private key|BEGIN (RSA|EC|OPENSSH)|admin|root:|telnet|wps|psk|wpa' \
  | sort -u | head -80 | tee -a "$REPORT"

sep "binwalk extraction (stage 4)"
if command -v binwalk >/dev/null; then
  ( cd "$WORK" && binwalk -ev "$IMG" 2>&1 | tail -30 ) | tee -a "$REPORT"
else echo "  [!] binwalk missing, skipping extraction"; fi

EXDIR="$(find "$WORK" -maxdepth 1 -type d -name '_*extracted' | head -1)"
if [[ -n "${EXDIR:-}" ]]; then
  sep "extracted rootfs: $(basename "$EXDIR")"
  sep "firmwalker sweep"
  if command -v firmwalker >/dev/null; then
    firmwalker "$EXDIR" 2>/dev/null | head -60 | tee -a "$REPORT"
  else
    echo "  [!] firmwalker not installed; doing inline scan instead" | tee -a "$REPORT"
    echo "  -- shadow/passwd --" | tee -a "$REPORT"
    find "$EXDIR" -name shadow -o -name passwd 2>/dev/null | head | tee -a "$REPORT"
    echo "  -- private keys / certs --" | tee -a "$REPORT"
    find "$EXDIR" \( -name '*.pem' -o -name '*.key' -o -name 'id_rsa*' -o -name '*.crt' \) 2>/dev/null | head -20 | tee -a "$REPORT"
    echo "  -- config files with creds --" | tee -a "$REPORT"
    grep -raiE 'password|passwd|secret|api[_-]?key' "$EXDIR/etc" "$EXDIR/usr" 2>/dev/null | head -30 | tee -a "$REPORT"
    echo "  -- init/startup scripts --" | tee -a "$REPORT"
    find "$EXDIR" \( -path '*/etc/init.d/*' -o -name 'rcS' -o -name 'rc.local' -o -name 'inittab' \) 2>/dev/null | head -20 | tee -a "$REPORT"
    echo "  -- web roots (cgi/www) --" | tee -a "$REPORT"
    find "$EXDIR" \( -iname 'www' -o -iname 'web' -o -iname 'htdocs' -o -iname 'cgi-bin' \) -type d 2>/dev/null | head | tee -a "$REPORT"
  fi
else
  echo "[!] no extracted dir found — image may be encrypted or non-standard FS. Try sasquatch / jefferson / ubireader." | tee -a "$REPORT"
fi

echo
echo "=============================================="
echo " report: $REPORT"
echo " workdir: $WORK"
echo "=============================================="
echo "Next: emulation (FirmAE/qemu), then proxy the web UI for command-injection/auth-bypass testing."
