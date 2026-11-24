#!/usr/bin/env bash
# =============================================================================
# verify_verbatim_harness.sh — prove a callback-bypass PoC runs the REAL
# framework core, not a hand-written stub. Re-runnable evidence artifact.
#
#   1. re-hashes every input file (framework distro zip + core files + plugin)
#   2. re-proves the dispatch excerpt embedded in the harness is BYTE-IDENTICAL
#      to the upstream core source
#   3. re-runs the exploit and asserts the invoice/order is marked PAID
#
# Adapt the four env vars + the two hard-coded paths below to the target.
# Exit 0 = all three stages passed. Non-zero = something drifted; DO NOT submit.
#
# Reference implementation: Blesta 6.0.2 + Plisio blesta-plugin (2026-09).
# =============================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

# ---- adapt these -----------------------------------------------------------
CORE="${BLESTA_CORE:-/tmp/blesta-core/blesta}"          # extracted framework root
PLUGIN="${PLISIO_PLUGIN:-$HERE/../repos/blesta-plugin/plisio.php}"  # vulnerable plugin
ZIP="${BLESTA_ZIP:-/tmp/blesta-core.zip}"               # official distro tarball
DISPATCH_REL="components/gateway_payments/gateway_payments.php"     # file with the dispatch
EXCERPT_START=528                                       # first line of the dispatch excerpt
EXCERPT_END=698                                         # last line (must close all braces)
HARNESS="$HERE/core_harness.php"                        # harness embedding the excerpt
RUNNER="$HERE/run.php"                                  # driver: feeds the forged callback
ANCHOR="// Attempt to validate the notification"        # first line of the excerpt (verbatim)
# ---------------------------------------------------------------------------

echo "=============================================================================="
echo " 1) INPUT FILE HASHES  (official distro + real core + real vendor plugin)"
echo "=============================================================================="
sha256sum "$ZIP" \
          "$CORE/$DISPATCH_REL" \
          "$CORE/app/controllers/callback.php" \
          "$CORE/components/gateways/lib/nonmerchant_gateway.php" \
          "$CORE/app/models/transactions.php" \
          "$PLUGIN" 2>&1

echo
echo "=============================================================================="
echo " 2) EXCERPT INTEGRITY  (harness excerpt  ==  upstream core, byte for byte)"
echo "=============================================================================="
python3 - "$CORE/$DISPATCH_REL" "$HARNESS" "$EXCERPT_START" "$EXCERPT_END" "$ANCHOR" <<'PY'
import sys, pathlib
src_p, harn_p, a, b, anchor = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
orig = pathlib.Path(src_p).read_text().splitlines()[a-1:b]
harn = pathlib.Path(harn_p).read_text().splitlines()
try:
    i = next(k for k, l in enumerate(harn) if l.strip() == anchor.strip())
except StopIteration:
    print("  ANCHOR NOT FOUND in harness -> FAIL"); sys.exit(1)
ex = harn[i:i+len(orig)]
print("  upstream lines :", len(orig))
print("  harness  lines :", len(ex))
ok = orig == ex
print("  BYTE-IDENTICAL :", ok)
if not ok:
    for x, y in zip(orig, ex):
        if x != y:
            print("  first DIFF upstream:", repr(x)); print("  first DIFF harness :", repr(y)); break
sys.exit(0 if ok else 1)
PY
EX=$?

echo
echo "=============================================================================="
echo " 3) EXPLOIT RE-RUN"
echo "=============================================================================="
BLESTA_CORE="$CORE" PLISIO_PLUGIN="$PLUGIN" php "$RUNNER"
RUN=$?

echo
if [ "$EX" -eq 0 ] && [ "$RUN" -eq 0 ]; then
  echo "RESULT: PASS  — verbatim core dispatch + forged callback => invoice PAID"
  exit 0
fi
echo "RESULT: FAIL  — excerpt drifted or exploit no longer fires; do NOT submit"
exit 1
