#!/usr/bin/env bash
# Verify that a locally-built Antelope (EOSIO) contract matches the code deployed on chain.
# Usage: verify-deployed-hash.sh <contract-dir> <contract-name> [api-endpoint]
#   e.g. verify-deployed-hash.sh contracts/agentvalid agentvalid
#
# A matching hash proves the source you reviewed IS the live on-chain code -> the finding is
# submittable. A mismatch means you are auditing unshipped code: say so, do not overclaim.
set -euo pipefail

DIR="${1:?usage: verify-deployed-hash.sh <contract-dir> <contract-name> [api-endpoint]}"
NAME="${2:?contract name required}"
API="${3:-https://api-xprnetwork-main.saltant.io}"

WASM="$DIR/assembly/target/$NAME.contract.wasm"
if [[ ! -f "$WASM" ]]; then
  echo "ERROR: $WASM not found — build first:  cd $DIR && npm install && npm run build" >&2
  exit 1
fi

LOCAL=$(sha256sum "$WASM" | awk '{print $1}')
DEPLOYED=$(curl -s -X POST "$API/v1/chain/get_code_hash" \
  -d "{\"account_name\":\"$NAME\"}" \
  | python3 -c 'import sys,json;print(json.load(sys.stdin).get("code_hash",""))')

echo "contract : $NAME"
echo "local    : $LOCAL"
echo "deployed : $DEPLOYED"
if [[ -n "$DEPLOYED" && "$LOCAL" == "$DEPLOYED" ]]; then
  echo "MATCH    : YES  (reviewed source == live code)"
else
  echo "MATCH    : NO   (reviewed source differs from live code)"
  exit 2
fi
