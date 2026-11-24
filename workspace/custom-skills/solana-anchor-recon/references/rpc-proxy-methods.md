# Typical /api/rpc proxy hardening on Solana dApps

Most production Solana frontends proxy their RPC calls through their own
backend to hide the real RPC provider (Helius/QuickNode/Triton) and to
apply a whitelist. Below is what a **well-hardened** proxy looks like,
based on production observations.

## Allowed methods (23 typical)

Read-only, needed by any wallet-connected frontend:

```
getAccountInfo         getBalance             getBlockTime
getEpochInfo           getFeeForMessage       getLatestBlockhash
getMinimumBalanceForRentExemption
getMultipleAccounts    getSignaturesForAddress  getSignatureStatuses
getSlot                getTokenAccountBalance   getTokenAccountsByOwner
getTransaction         isBlockhashValid
simulateTransaction    ← the important one for attackers
```

## Blocked methods (32+ typical)

Write, expensive, or backend-fingerprinting:

```
sendTransaction        sendRawTransaction     requestAirdrop
getProgramAccounts     ← blocked: expensive scan
getSupply              getBlock               getBlocks
getVersion             getIdentity            getClusterNodes
getEpochSchedule       getGenesisHash         getHealth
getSlotLeader          getSlotLeaders         getTransactionCount
getVoteAccounts        getStakeActivation
accountSubscribe       accountUnsubscribe
logsSubscribe          programSubscribe       slotSubscribe
minimumLedgerSlot
```

## Fingerprinting the whitelist

```bash
for m in <METHODS>; do
  err=$(curl -s -X POST https://TARGET/api/rpc \
    -H 'Content-Type: application/json' \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$m\"}" \
    | jq -r '.error.message // "OK"')
  echo "$m → $err"
done
```

Common response patterns:
- `method not allowed: X` → hard-blocked at proxy
- `` `params` should have at least N argument(s) `` → **ALLOWED** but you supplied empty params (retest with valid params)
- `Invalid params: ...` → ALLOWED, just wrong shape
- Actual JSON `result` → ALLOWED and worked with no params

## Why `simulateTransaction` allowed = attacker gold

The frontend needs to preview txs (show gas cost, expected outcome, error
messages before user signs). So `simulateTransaction` is almost always
open. Combined with `sigVerify=false`, this gives you:

1. **Free tx probing** — no SOL spent, no on-chain state changed
2. **Full log output** — including `AnchorError thrown in <path>:<line>`
3. **`replaceRecentBlockhash: true`** — bypasses stale-blockhash issues
4. **Admin auth probing** — swap the admin signer field to attacker, see if the program's own logic rejects. Anchor's `has_one` check runs during instruction execution, not signature verification — so `sigVerify=false` doesn't bypass the auth check.

## `getProgramAccounts` blocked

This is common because it's expensive (full DB scan on the RPC side).
Workaround: hit devnet/mainnet directly at `api.devnet.solana.com` or
`api.mainnet-beta.solana.com`. These endpoints allow `getProgramAccounts`
with reasonable filters — they don't need to go through the target's proxy.

## Rate limiting

Even allowed methods have rate limits. If you get `429` or unexplained
timeouts, add `sleep 0.5` between calls, or rotate through the residential
proxy. Serious testing volumes should use the direct RPC (which is free
for reads and doesn't count against the target's quota).
