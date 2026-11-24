#!/usr/bin/env bash
# verify-visual-deception.sh — prove a document shows one thing to the human/vision
# layer and another to the machine text-extraction layer.
#
# Usage: verify-visual-deception.sh <file.html|file.docx|file.pdf> [outdir]
#
# Prints:
#   [RENDERED]  text a human/OCR/vision model sees
#   [EXTRACTED] text a parser / copy-paste / LLM text layer reads
#   verdict: DIVERGENT (deception present) or IDENTICAL
#
# Requires: chromium|chromium-browser|google-chrome, tesseract-ocr,
#           poppler-utils (pdftoppm/pdftotext), python3 (+Pillow for ink check),
#           libreoffice/soffice only for .docx rendering.
set -uo pipefail

TARGET="${1:?usage: $0 <file.html|file.docx|file.pdf> [outdir]}"
[ -f "$TARGET" ] || { echo "no such file: $TARGET" >&2; exit 1; }
EXT="${TARGET##*.}"
OUT="${2:-$HOME/deception-proof}"
mkdir -p "$OUT"
TARGET="$(readlink -f "$TARGET")"

# --- locate a browser -------------------------------------------------------
CHROME=""
for c in chromium chromium-browser google-chrome google-chrome-stable; do
  if command -v "$c" >/dev/null 2>&1; then CHROME="$(command -v "$c")"; break; fi
done

# --- 1. RENDERED layer ------------------------------------------------------
render_png() {   # $1 = source file, $2 = out png
  case "$EXT" in
    html|htm)
      [ -n "$CHROME" ] || { echo "(no browser found; cannot render HTML)" >&2; return 1; }
      # PITFALL: without virtual-time-budget the screenshot fires before @font-face
      # loads and comes out BLANK. PITFALL: snap chromium can't write to /tmp.
      "$CHROME" --headless=new --no-sandbox --disable-gpu --hide-scrollbars \
        --allow-file-access-from-files --force-device-scale-factor=2 \
        --virtual-time-budget=8000 --run-all-compositor-stages-before-draw \
        --window-size=1200,400 --screenshot="$2" "file://$1" >/dev/null 2>&1
      ;;
    docx)
      command -v soffice >/dev/null 2>&1 || { echo "(no LibreOffice; cannot render DOCX)"; return 1; }
      soffice --headless --convert-to pdf --outdir "$OUT" "$1" >/dev/null 2>&1
      pdftoppm -png -r 200 "$OUT/$(basename "${1%.docx}").pdf" "$OUT/render" >/dev/null 2>&1
      mv "$OUT"/render-*.png "$2" 2>/dev/null
      ;;
    pdf)
      pdftoppm -png -r 200 "$1" "$OUT/render" >/dev/null 2>&1
      mv "$OUT"/render-*.png "$2" 2>/dev/null
      ;;
    *) echo "unsupported extension: $EXT" >&2; return 1 ;;
  esac
}

# --- 2. EXTRACTED layer -----------------------------------------------------
extract_text() {
  case "$EXT" in
    html|htm) python3 - "$1" <<'PY'
import re,sys,html
s=open(sys.argv[1],encoding='utf-8',errors='replace').read()
s=re.sub(r'<script.*?</script>','',s,flags=re.S|re.I)
s=re.sub(r'<style.*?</style>','',s,flags=re.S|re.I)
s=re.sub(r'<[^>]+>','',s)
print(' '.join(html.unescape(s).split()))
PY
      ;;
    docx) unzip -p "$1" word/document.xml 2>/dev/null \
            | python3 -c "import sys,re; print(''.join(re.findall(r'<w:t[^>]*>(.*?)</w:t>', sys.stdin.read(), re.S)))" ;;
    pdf)  pdftotext "$1" - 2>/dev/null ;;
  esac
}

PNG="$OUT/rendered.png"
RENDERED=""; EXTRACTED=""
if render_png "$TARGET" "$PNG"; then
  # blank-render guard: an all-white PNG means the render failed, not an empty doc
  INK=$(python3 - "$PNG" <<'PY'
import sys
try:
    from PIL import Image
    im=Image.open(sys.argv[1]).convert('RGB')
    px=im.getdata()
    print(sum(1 for p in px if p!=(255,255,255)))
except Exception as e:
    print(-1)
PY
)
  if [ "$INK" = "0" ]; then
    echo "(WARNING: rendered PNG has 0 ink pixels — render likely failed / fonts not loaded)" >&2
  fi
  RENDERED=$(tesseract "$PNG" - 2>/dev/null | tr '\n' ' ' | sed 's/  */ /g')
else
  echo "(rendered layer unavailable — install browser/LibreOffice)" >&2
fi

EXTRACTED=$(extract_text "$TARGET" | tr '\n' ' ' | sed 's/  */ /g')

echo "=============================================================="
echo "file       : $TARGET"
echo "--------------------------------------------------------------"
echo "[RENDERED] : ${RENDERED:-<none>}"
echo "--------------------------------------------------------------"
echo "[EXTRACTED]: ${EXTRACTED:-<none>}"
echo "--------------------------------------------------------------"
norm() { printf '%s' "$1" | tr 'A-Z' 'a-z' | tr -cd 'a-z0-9'; }
if [ -n "$RENDERED" ] && [ "$(norm "$RENDERED")" != "$(norm "$EXTRACTED")" ]; then
  echo "VERDICT    : DIVERGENT — rendered layer != extracted layer (deception present)"
else
  echo "VERDICT    : identical / inconclusive"
fi
echo "=============================================================="
echo "artifacts  : $PNG"
