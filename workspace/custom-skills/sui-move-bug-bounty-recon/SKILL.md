
# Sui / Move Bug Bounty Recon

Sui uses the Move object model, NOT Solidity/Anchor. Different toolchain, different RPC, different source-locating tricks. This skill is the recon-phase sibling of `solana-bug-bounty-recon` and `evm-smart-contract-audit`.

## Phase 0 — Scope Gate (DO THIS FIRST)

Before burning cycles: **is there an authorized bounty program?** Grep the site, docs, and JS bundle for `immunefi|hats\.finance|hackenproof|cantina|sherlock|bounty|security@`. If NONE exists, there is no scope and no payout channel — findings can only go via responsible disclosure (Discord / security contact), not a bounty claim. Tell the user this up front; don't imply a payout that can't happen. (Verified case: Mole Protocol / mole.fi had zero public program.)

## Phase 1 — Locate Source + Deployed Package

Sui protocols publish Move source on GitHub AND deploy a package on-chain. You need at least one. Order of attack:

### 1.1 Find the GitHub org
```bash
# site homepage usually links github in the JS bundle, not the HTML
curl -sL -A "Mozilla/5.0" https://TARGET/ -o /tmp/t.html
grep -oiE 'href="[^"]+"|src="[^"]+"' /tmp/t.html          # get JS bundle names
curl -sL "https://TARGET/js/app.HASH.js" | grep -oiE 'https://github.com/[a-zA-Z0-9_./-]+' | sort -u
# then enumerate the org's repos
curl -s "https://api.github.com/orgs/ORG/repos?per_page=100" \
  | grep -oiE '"name": *"[^"]+"|"pushed_at": *"[^"]+"' | paste - -
```

### 1.2 CRITICAL: org API caches repo names AFTER they go private
The `/orgs/ORG/repos` listing can still show repos that are now **private/404**. Confirm each is actually clonable:
```bash
for r in repo1 repo2; do
  echo -n "$r -> "; curl -sL -m 15 -o /dev/null -w "%{http_code}\n" "https://github.com/ORG/$r"
done
# 404 on github.com + 404 on codeload + 404 on raw.githubusercontent = PRIVATE. Cannot clone.
```
If the interesting `*-sui-move*` / `*-contracts` repos are all 404 → source is gated. Don't fight `git clone` (returns misleading "could not read Username" auth-prompt error on a private/nonexistent repo). Pivot to on-chain (Phase 2) or ask the user for a zip.

### 1.3 On-chain addresses from DefiLlama adapter (GOLD)
If the protocol reports TVL, its DefiLlama adapter is PUBLIC and contains deployed addresses + object-field paths — even when the protocol's own repo is private:
```bash
curl -s "https://api.github.com/repos/DefiLlama/DefiLlama-Adapters/contents/projects/PROTOCOL" \
  | grep -oiE '"name": *"[^"]+"'
curl -s "https://raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters/main/projects/PROTOCOL/lyf.js"
```
The adapter reveals: package/config URLs (e.g. `raw.githubusercontent.com/ORG/repo/main/.sui_mainnet.json`), Move struct type strings (`vault::VaultInfo`, `swap::TokenPairReserve`, `pancake_worker::WorkerInfo`), and object-ID accessor paths. This maps the on-chain surface for free. NOTE: a 64-hex `account` in the adapter may be the **Aptos** deployer, not Sui — Sui protocols are often multi-chain (Aptos + Sui). Verify which chain via RPC (Phase 2) before assuming.

## Phase 2 — Query Sui On-Chain

### 2.1 Public JSON-RPC on fullnode.mainnet.sui.io is DEPRECATED
`https://fullnode.mainnet.sui.io` now returns `-32601 Method not found ... JSON-RPC deprecated`. Use a working third-party RPC:
```bash
# WORKING (as of 2026): publicnode, suiscan, blockvision-endpoint
RPC=https://sui-rpc.publicnode.com          # or https://rpc-mainnet.suiscan.xyz
curl -s -m 15 "$RPC" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getObject","params":["0xPKG_OR_OBJ",{"showType":true,"showOwner":true,"showContent":true}]}'
# DEAD: fullnode.mainnet.sui.io (deprecated), blastapi (shut down, points to Alchemy)
```
Response `{"error":{"code":"notExists"}}` = that object ID isn't on Sui (likely an Aptos/other-chain ID). A real package returns `type` and module info.

### 2.2 Get the package ID
The frontend's config file (`api/SuiMainnet/data.json` or `.sui_mainnet.json`) holds package + object IDs but is often **403/404-locked** or pulled. Alternatives:
- **User's own tx history**: ask user for a Suiscan link to any tx they made on the app → the `Transaction` → package in the `MoveCall`.
- **Suiscan/SuiVision search** for the protocol name → published package.
Once you have the package ID:
```bash
curl -s "$RPC" -H 'Content-Type: application/json' \
  -d '{"jsonrpc":"2.0","id":1,"method":"sui_getNormalizedMoveModulesByPackage","params":["0xPKG"]}'
```
This returns the full module ABI (structs, functions, visibility, params) — audit this directly, no source needed. For bytecode: `sui_getObject` with `showBcs` then disassemble with `sui move disassemble` if you have the CLI.

## Phase 3 — Move Attack Surface

Once you have modules (source OR normalized ABI), map Move-specific bug classes:

| Class | What to look for |
|---|---|
| **Missing capability check** | `public entry fun` that mutates shared objects without requiring an `AdminCap`/`OwnerCap` param |
| **Shared-object race** | Functions taking `&mut` shared objects — Sui allows concurrent access; check invariant ordering |
| **Type-argument confusion** | Generic `Coin<T>` functions that don't constrain `T` — wrong-coin deposit/withdraw |
| **Oracle / price** | Leveraged farms derive price from AMM `current_sqrt_price` / reserves → flash-loan manipulable |
| **Rounding / precision** | Integer division before multiply in share/debt math (vault `vault_debt_val`, `reserve_pool`) |
| **Reward / debt accounting** | `VaultInfo.coin` vs `vault_debt_val` — under/over-count on borrow/repay |
| **`init` re-entry** | One-time-witness pattern bypass; `public fun init` callable twice |
| **Locked funds** | Value credited to a field with no withdraw path (same class as the PCN `sol_reserve` finding) |
| **Fail-open signature sentinel** | Verifier returns `@0`/sentinel for "unverified" (e.g. scheme 5 ZK) and callers do `signatory == @0 \|\| ...` → auth bypass for any account. See `references/move-audit-and-poc.md` §1 |
| **Sentinel persisted into state** | Second-order of the above: the sentinel-tainted value (`user`/`signer` decoded from an attacker payload) is written by a setter with no `!= @0` guard → `has_permission(@0)` becomes true forever. Defeats the one strict call site AND survives a predicate-only patch. See §1b |
| **Owned-vs-shared gate** | `transfer::transfer` (owned = privileged) vs `share_object` (shared = permissionless). Classify each entry fn's object params to know real attacker reachability. See §2 |

Leveraged-yield-farm (LYF) protocols like Mole = vaults + workers + CLMM positions. Attack the debt/share math and the worker's LP-position valuation.

## Phase 4 — Audit → Real-Module PoC

Once recon lands source, the audit + PoC playbook is in **`references/move-audit-and-poc.md`**:
- §1 fail-open `@0` signature-verification bypass (Move bug class + grep recipes)
- §1b second-order: the sentinel persisted into account state via an unguarded setter (defeats a predicate-only fix)
- §2 the owned-vs-shared reachability gate (decide Critical vs Medium honestly)
- §3 the minimal `sui move test` package that runs the REAL modules (with negative controls)
- §3b the full-package build recipe (`#[test_only]` friend stubs, reuse an existing friend module, legacy-edition `let mut` trap, `#[test_only]` destructor for no-`drop` structs)
- §4 security contact discovery (`.well-known/security.txt`; many Sui projects are self-hosted VDP, not Immunefi)
- `suiup` install for the Sui CLI

## Pitfalls

1. **Scope gate first.** No bounty program = no payout. State it before promising anything.
2. **Org repo listing lies** — cached names survive going private. Always HTTP-check each repo for 404.
3. **`git clone` on a private repo** prints "could not read Username for github.com" (auth prompt), NOT a clean 404 — don't misread it as a network bug. Use `GIT_TERMINAL_PROMPT=0` and check the HTTP code instead.
4. **fullnode.mainnet.sui.io JSON-RPC is dead** — use publicnode/suiscan RPC.
5. **A hex account in DefiLlama adapters may be Aptos, not Sui** — multi-chain protocols. Verify chain via `notExists` RPC probe.
6. **Never fabricate Move findings** from a locked repo. If source is private and package ID unknown, the honest deliverable is: "blocked — need source zip OR package ID," not invented vulns.
7. **`app.SITE/api/...` returns nginx 403** — that's server-side lockdown, not a bypass target; don't chase it as a vuln unless the task is web-layer.
8. **Triage reachability before severity.** A real bug in a sequencer-gated path is Medium/High, not Critical — check owned-vs-shared object ownership first (`references/move-audit-and-poc.md` §2). This user rejects inflated bounty/severity estimates.
9. **Re-verify report claims against the source before submitting.** Drafts drift — the Bluefin draft mislabeled `exchange.move:1519` as `liquidate` (it's `adjust_margin`), `:2922` as `adjust_leverage` (it's `close_position`), and claimed `verify_liquidation_signature` returns `@0` when it **aborts**. A green PoC proves the mechanism, not the prose. List the enclosing `fun` for every cited line before shipping. Recipe: `references/move-audit-and-poc.md` §Pitfalls #6.
10. **A fail-open sentinel is rarely just a bad predicate — follow it into storage.** The high-value version of the bug is the sentinel getting **persisted** (attacker-controlled `user`/`signer` written by a setter with no `!= @0` guard), which defeats the one *strict* call site and **survives a predicate-only patch**. When you find `signatory == @0 || ...`, immediately check every setter that can store a signer, and confirm your proposed fix actually clears persisted `@0`. The tell is **asymmetry**: the codebase guards `@0` in most setters but omits it in exactly the one feeding an auth check. See `references/move-audit-and-poc.md` §1b.

## Related
- `solana-bug-bounty-recon` — same recon philosophy, Anchor/Solana specifics.
- `evm-smart-contract-audit` — Foundry PoC workflow for EVM targets.
- `web3-audit` / `crypto-bug-bounty` — DeFi bug-class references.
