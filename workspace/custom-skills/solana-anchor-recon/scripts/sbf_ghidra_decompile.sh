#!/usr/bin/env bash
# Headless-decompile a stripped Solana SBF program with Ghidra's eBPF processor.
#
# Usage:  sbf_ghidra_decompile.sh prog.so [out.c]
#
# Requires: Ghidra (GHIDRA_HOME, default /opt/ghidra), java, and DumpDecomp.java
# sitting next to this script (scriptPath is set to this script's directory).
#
# Notes:
#  - The postScript MUST be a .java file in PyGhidra-based installs (not Jython).
#  - On a ~700 KB .so this takes minutes -> run it backgrounded with notify.
set -euo pipefail

SO="${1:?usage: $0 prog.so [out.c]}"
OUT="${2:-$(dirname "$SO")/decomp_all.c}"
GH="${GHIDRA_HOME:-/opt/ghidra}"
PROJ="${GHIDRA_PROJ:-/tmp/ghidra_proj}"
HERE="$(cd "$(dirname "$0")" && pwd)"

rm -rf "$PROJ"; mkdir -p "$PROJ"

"$GH/support/analyzeHeadless" "$PROJ" bp \
  -import "$SO" \
  -processor "eBPF:LE:64:default" \
  -scriptPath "$HERE" \
  -postScript DumpDecomp.java "$OUT" \
  -deleteProject 2>&1 | tail -20

echo "-> $OUT"
wc -l "$OUT"
