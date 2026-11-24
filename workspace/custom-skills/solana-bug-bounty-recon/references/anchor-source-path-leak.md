# Anchor Source-File Path Leak via `AnchorError` Logs

## The pattern

Anchor's default `AnchorError` stringification embeds `file!()` + `line!()` from `source!()` macro. In production, this leaks absolute source paths through `sol_log` into on-chain transaction logs, which are then served verbatim by any RPC proxy.

Example log line (verified live on popi.wtf):
```
Program log: AnchorError thrown in programs/popilaunch/src/instructions/set_keeper.rs:34.
             Error Code: Unauthorized. Error Number: 6039.
             Error Message: Caller is not authorized to perform this action.
```

## Why it's a bug (bounty class)

- **Repository structure disclosure** — reveals internal folder layout (`programs/<progname>/src/instructions/`) + exact filenames without repo access.
- **Line-number oracle** — pinpoints location of every constraint check; useful for exploit chaining if source ever leaks.
- **Persistence** — the disclosure lives forever in on-chain logs (immutable).

Severity: **P4-P5 / info disclosure**. Realistic payout range **$25-75** at most launchpad bounty programs. Recognized bug class in Solana security audits (Anchor issue #2244).

## Trigger (no SOL needed)

Any admin-gated ix works because Anchor's `has_one` / `require!` check fires early and emits the error before any state change:

1. Take a whale wallet address (with SOL) as fee payer.
2. Build ix (e.g. `set_keeper`) with:
   - `admin` signer = arbitrary attacker key
   - `global_config` = real GlobalConfig PDA
3. Simulate via `simulateTransaction` with `sigVerify=false`:
   ```json
   POST /api/rpc  (or direct devnet RPC)
   {"jsonrpc":"2.0","id":1,"method":"simulateTransaction",
    "params":["<base64_tx>",{"encoding":"base64","sigVerify":false,"replaceRecentBlockhash":true}]}
   ```
4. Read `.result.value.logs[]`. Search for `.rs:` substring.

Not every ix leaks — depends which Anchor version + which check macro the dev used. In popi, `set_keeper` leaked but 8 other admin ix didn't (they use plain `err!()` without `.with_source()`). Iterate through all admin ix to enumerate leaking sites.

Templates that reproduce: `templates/admin_bypass_template.py`.

## Report template body

```markdown
# Information Disclosure: Solana Program Source File Paths Leaked via Anchor Error Logs

**Severity**: Low (P5)
**Category**: Information Disclosure
**Target**: Solana program `<PROGRAM_ID>`

## Summary
The <NAME> Solana program compiles with the default Anchor `AnchorError`
formatting, which embeds the absolute source file path and line number of
every `require!` / `has_one` / constraint failure into the on-chain program
log. Any user can trigger these errors via `simulateTransaction` (no SOL,
no signature needed) and read the internal repository layout from public
RPC logs.

## Steps to Reproduce
[whale fee_payer + attacker signer + sigVerify=false — see PoC]

## PoC (verified live)
[curl command + trimmed logs array]

## Root Cause
Anchor macros `require!`, `has_one`, `#[account(constraint=…)]` expand to
`Err(Error::from(code).with_source(source!()))` where `source!()` embeds
`file!()`+`line!()`.

## Recommendation
Rebuild with `anchor-lang` features that strip source locations
(anchor-lang >= 0.29 has `no-log-ix-name` and related). OR patch the
`error!()` invocations to use bare `err!(ErrorCode::X)` without `.with_source()`.

Verify fix by re-running PoC — expected new log:
`Program log: AnchorError. Error Code: Unauthorized. Error Number: 6039.`

Reference: https://github.com/coral-xyz/anchor/issues/2244
```

## Related patterns to test at the same time (often colocated bugs)

- `assert_eq!` in Anchor programs prints `Left:` + `Right:` pubkeys in logs (verified in popi `set_graduation_threshold`) — same OpSec class, same bounty tier.
- `msg!("something {}", pubkey)` calls in dev code that shipped to prod — grep logs for wallet addresses appearing in ways that reveal internal keypair usage.
