# Sui / Move Audit + PoC — beyond recon

Companion to SKILL.md. Covers the phases AFTER you have source: finding the bug class,
proving attacker reachability, and building a runnable `sui move test` PoC against the
REAL modules (not a stub).

---

## 1. Move-specific bug class: fail-open sentinel in signature verification

**The pattern (high value, recurs across Sui perp/DEX code):** an on-chain signature
verifier returns a *sentinel value* to mean "I did not verify this" — and callers treat
that sentinel as *authorized*.

Real case — Bluefin Pro `bluefin_cross_margin_dex`:

```move
// signature.move:378-385
} else if (scheme == 5){          // "ZK" wallet
    // We do not verify zk signatures on-chain and trust off-chain auth gateway...
    return @0                     // <-- zero address = "unverified", returned as a value
}
```

Every caller then does:

```move
// exchange.move:383-386  (withdraw_from_bank)
let signatory = signature::verify(payload, signature, b"Bluefin Pro Withdrawal");
// zk wallet signature are not verified and the signatory returned is zero address
assert!(signatory == @0 || signatory == account, errors::invalid_permission());
```

Because the predicate is `signatory == @0 || ...`, **any blob ≥65 bytes whose first byte
is `5`** (scheme byte) satisfies the check for **any** account — no private key, no public
key, no ZK proof.

**Verified fail-open call sites** (file:line = the `assert!(signatory == @0 || ...)` line,
each confirmed against the real source — do NOT trust a line number you didn't re-check):

| Action | File:line | Predicate |
|---|---|---|
| `withdraw_from_bank` (funds out) | `exchange.move:386` | `signatory == @0 \|\| signatory == account` |
| `authorize_account` (delegate a signer) | `exchange.move:519` | `signatory == @0 \|\| signatory == account` |
| `adjust_margin` | `exchange.move:1519` | `signatory == @0 \|\| has_permission(...)` |
| `adjust_leverage` | `exchange.move:1802` | `signatory == @0 \|\| has_permission(...)` |
| `close_position` (delisted market) | `exchange.move:2922` | `signatory == @0 \|\| has_permission(...)` |
| `batch_trade` / `trade` (via `validate_order`) | `exchange.move:3535` | `signatory == @0 \|\| has_permission(...)` |

**Safe contrast sites** (correctly omit the `@0` escape hatch — cite these to show the devs
knew the pattern): `liquidate` (`exchange.move:1265-1271`, `has_permission` only),
`apply_funding_rate` (`:2063`), `deleverage` (`:2664`). Note `verify_liquidation_signature`
(`signature.move:167`) **aborts** (`deprecated_function`) — it does NOT `return @0`; an
earlier draft of this reference got that wrong.

### 1b. Second-order: the sentinel gets PERSISTED (the connected bug — always hunt this)

The `@0` sentinel is not only *compared* — it can be **written into account state**, and
that is a strictly worse bug than the predicates. When you find a fail-open sentinel, do
NOT stop at the `signatory == @0 ||` call sites. Follow the sentinel-tainted value into any
**storage primitive** and check whether the *stored* value is re-read as authorization.

Bluefin `authorize_account` (`exchange.move:473-540`) is the model:

```move
let signatory = signature::verify(payload, signature, b"Bluefin Pro Authorize Account");
assert!(signatory == @0 || signatory == account, errors::invalid_permission());  // :519
let (ids_addr, account_addr, user, status, salt, signed_at) =
        bcs_handler::dec_authorization(payload);   // `user` = attacker-controlled, NO @0 check :492
let account_state = data_store::get_mutable_account(ids, account_addr);
account::set_authorized_user(account_state, user, status);   // :540 persists `user`
```

```move
// account.move:278 — NO @0 guard
public (friend) fun set_authorized_user(account: &mut Account, user: address, authorized: bool) {
    if (authorized) { vector::push_back(&mut account.authorized, user); } ...
}
// account.move:756
public fun has_permission(account: &Account, signatory: address): bool {
    signatory == account.address || vector::contains(&account.authorized, &signatory)
}
```

**Why this matters (and why a naive fix fails):** after a scheme-5 blob writes `@0` into
`account.authorized`, `has_permission(@0)` is `true`. So:

1. It defeats the one call site that correctly omits the `@0` escape hatch — `liquidate`
   (`exchange.move:1265-1271`, `has_permission` only). A forged scheme-5 blob now authorizes
   liquidation on a whitelisted liquidator account.
2. **It SURVIVES a predicate-only patch.** Deleting the `|| signatory == @0` clauses (the
   obvious fix) leaves the *stored* `@0` grant intact. The complete fix must ALSO reject `@0`
   as a delegate in `authorize_account` / `set_authorized_user` (and ideally strip existing
   `@0` entries). Always check whether your proposed fix actually clears the persisted state.

**Hunt recipe** — for every verifier sentinel, trace taint into setters:
```bash
grep -nE "set_[a-z_]*\(|push_back|insert\(" *.move | grep -iE "user|signer|authoriz|owner|operator|admin"
# then read each setter and look for a missing `!= @0` / can_not_be_zero guard
```
**The tell:** the codebase already guards `@0` in *some* setters (`set_operator`
`data_store.move:434`, `create_user_account` `exchange.move:62`, pool setters
`exchange.move:2570`, `perpetual.move:435/441`, sequencer setter `data_store.move:1044`) but
omits it in exactly the setter that feeds an authorization check. That asymmetry IS the bug —
enumerate all `!= @0` guards, then find the setter that lacks one.

### How to hunt it
```bash
# find the verifier(s)
grep -nE "fun (verify|verify_.*signature|recover.*signer)" *.move
# find sentinel returns that skip verification
grep -nE "return @0|@0x0|== @0|!= @0" *.move
# find the authorization predicates callers use
grep -nE "signatory ==|has_permission\(|invalid_permission|invalid_signature" *.move
```
Cross-reference: any `@0` produced by a verifier + any `== @0` in an auth predicate = candidate.

### Root-cause framing for the report
The contract encodes "unverified" as a value that means "authorized". It cannot
distinguish a genuine ZK authorization from a forged one, so the on-chain check provides
**zero** protection. Severity depends entirely on whether the off-chain gateway truly
verifies (see §2 — this is where honest triage happens).

---

## 2. Reachability gate — owned vs shared objects (do this BEFORE claiming severity)

Move entry functions take object refs. The **ownership of those objects is the real access
control**, not the function visibility. Determine it before you claim "anyone can call X".

```move
// data_store.move — creation/sharing
transfer::transfer(ids, sequencer);   // OWNED by sequencer -> only sequencer can pass &mut IDS
share_object(eds);                    // SHARED -> ANYONE can pass &mut EDS
```

- An `entry fun` that needs `&mut InternalDataStore` (owned) is **sequencer-only** even
  though it's `public entry`.
- An `entry fun` that only needs `&mut ExternalDataStore` (shared) is **permissionless**.

Find the gate:
```bash
grep -nE "share_object|transfer::transfer|public_transfer|freeze" data_store.move
# then list each entry fn's params and classify:
for f in *.move; do awk '/entry fun/{print FILENAME":"NR": "$0}' "$f"; done
```

**Bluefin outcome:** the only permissionless money fn was `deposit_to_asset_bank`; every
signed action (withdraw/authorize/trade/liquidate/adjust) required the sequencer-owned IDS.
So the `@0` bypass is a **Medium–High** ("on-chain auth is a no-op for ZK wallets; the
non-custodial guarantee is void if the gateway is bypassed"), NOT a permissionless
"anyone drains anyone" Critical. State this honestly — do not inflate.

---

## 3. Runnable PoC harness (`sui move test`) against REAL modules

Goal: prove the vuln on the *actual* source, not a re-implementation. Two proven shapes:

### 3a. Minimal std-only package (fastest, no deps on the rest of the repo)
If the vulnerable module only depends on `std` + a couple of sibling modules, copy just
those and test them in isolation.

```
poc/
  Move.toml
  sources/        # copied verbatim from the real repo
    signature.move
    errors.move
    constants.move
  tests/
    signature_poc_tests.move
```

`Move.toml`:
```toml
[package]
name = "bluefin_cross_margin_dex"
version = "1.0.0"

[dependencies]
Sui = { git = "https://github.com/MystenLabs/sui.git",
        subdir = "crates/sui-framework/packages/sui-framework", rev = "testnet" }

[addresses]
bluefin_cross_margin_dex = "0x0"
```

Find the module's real deps first:
```bash
grep -n "use bluefin_cross_margin_dex::" signature.move   # which sibling modules it needs
```

### 3b. Full-package build (when 3a's module pulls in the world)
Copy the whole `sources/` tree; the package usually compiles even if it isn't a lib you
can easily drive. Verify with `sui move build` and grep for real `error` lines (ignore
`warning[WC04037]: deprecated usage` — that's just `vector::empty` → `vector::empty<..>`).

**Two blockers you WILL hit, and the fixes (verified on Bluefin, sui 1.80.1):**

1. **`#[test_only] friend` modules must exist as modules.** Real modules declare
   `#[test_only] friend pkg::test_utils;` etc. When you copy `sources/` alone, compilation
   fails with `Unbound module`. Create **empty stub modules** with the same names:
   ```move
   #[test_only]
   module bluefin_cross_margin_dex::test_liquidations { }
   ```
   Generate one per missing friend. Find them:
   ```bash
   grep -rhn "friend [a-z_]*::" sources/*.move | sed 's/.*:://;s/;.*//' | sort -u
   # any friend name with no matching sources/<name>.move -> needs a stub
   ```
   First check whether the real modules *call* those test modules (`grep -rn "test_utils::" sources/`);
   if not (usual case), empty stubs suffice.

2. **Drive the real module from the friend module that already exists.** Don't add a new test
   module — reuse an existing `#[test_only] friend` name (Bluefin: `test_utils`) so you get
   `public (friend)` access to the real `initialize` / `set_authorized_user` /
   `has_permission` with **zero edits to production code**. Putting your tests *inside* the
   friend module is what makes the PoC exercise the real API instead of a copy.

3. **Legacy Move edition: `let mut` is a syntax error.** This package compiles under the
   legacy edition where `mut` is not a keyword — `let mut acct = ...` parses as a *variable
   named `mut`* and later use of `acct` fails with `Unbound variable`. Locals are mutable by
   default; just write `let acct = ...;`. (Symptoms: `error[E01002] Unbound variable`,
   `Unused let binding`.)

4. **A struct with `store` but no `drop` cannot be dropped by a test.** `Account` is
   `has store` only, so a test that creates one fails with
   `error[EC06001] unused value without 'drop'`. Add a `#[test_only]` destructor to the real
   module (test-only, zero production surface) and call it at the end of each test:
   ```move
   #[test_only]
   public (friend) fun destroy_account_for_testing(account: Account) {
       let Account { address: _, authorized: _, assets: _, cross_positions: _,
                     isolated_positions: _, trading_fees: _, is_institution: _, fee_asset: _ } = account;
   }
   ```
   Field names are module-private, so the destructor MUST live inside the owning module.

**Ship it to a box that has the Sui CLI** and run there (e.g. the BB VPS at
`/root/.local/bin/sui`); `scp` the sources over, then `sui move test` and grep the summary:
```bash
sui move test 2>&1 | grep -iE "\[ PASS|\[ FAIL|Total tests|Test result|error\["
```
Success line: `Test result: OK. Total tests: 6; passed: 6; failed: 0` (2 connected-bug
tests + the package's own pre-existing tests, all green).

### Test design that survives review
- **Exploit test** calls the *exact* real function the entry point calls, with the exact
  same intent message. Bluefin: `signature::verify(payload, sig, b"Bluefin Pro Withdrawal")`
  (matches `exchange.move:383`).
- **Forge the input realistically**: `[0x05, 0xAB × 64]` = scheme byte 5 + garbage.
- **Assert the caller's predicate passes** for a victim account you hold no key for:
  `assert!(signatory == @0 || signatory == VICTIM_ADDR, 0)`.
- **Add ≥2 negative controls** so the PoC shows *only* the bad path bypasses:
  same garbage under ed25519 (scheme 0) → aborts; unsupported scheme → aborts.
- Save the run log as `RESULT.txt` and attach it — reviewers trust captured output.

Run:
```bash
cd poc && sui move test        # -> "Test result: OK. Total tests: 5; passed: 5; failed: 0"
```

### Toolchain install (fresh box)
```bash
curl -sSfL https://raw.githubusercontent.com/MystenLabs/suiup/main/install.sh | sh
export PATH=$HOME/.local/bin:$PATH
suiup install sui            # verified: sui 1.80.1
```
`rev = "testnet"` pulls the framework on first build (needs network; ~minutes).

---

## 4. Security contact for Sui protocols

Sui projects often run a **self-hosted VDP**, not an Immunefi program. Check:
```bash
curl -sSL https://TARGET/.well-known/security.txt        # RFC 9116 -> mailto: + Policy:
curl -sSL https://TARGET/security.txt
# Immunefi: https://immunefi.com/bug-bounty/<name>/  (307->/information/ = exists; "Not Found" = none)
```
Bluefin: `.well-known/security.txt` → `security@seed.im`, policy
`bluefin.io/reporting-security-vulnerability`. Immunefi had **no** Bluefin program.

---

## Pitfalls

1. **Don't overclaim from a `@0` bypass alone.** Prove the entry fn is actually callable by
   the attacker (owned-vs-shared, §2) or you're reporting a Medium as a Critical. Users
   reject inflated severities.
2. **The sentinel may be "by design".** Report the *consequence* (on-chain auth is a no-op
   for scheme N; non-custodial guarantee void), not "the devs forgot". Frame as defense-in-depth
   failure with a concrete exploit path.
3. **`sui move build` prints many `deprecated usage` warnings** — filter them; only real
   `error[E...]` lines matter.
4. **Copy modules verbatim** into the PoC package — editing the "real" source undermines the
   whole point of a real-module PoC.
5. **Watch disk on the audit box** — a full Sui framework build + target dir is heavy.
6. **Re-verify EVERY `file:line`→function mapping and every "function X does Y" claim in
   the draft report before submitting.** Draft reports (yours or a prior session's) drift:
   the Bluefin draft claimed `1519 = liquidate` (actually `adjust_margin`),
   `2922 = adjust_leverage` (actually `close_position`), and that
   `verify_liquidation_signature` returns `@0` (it **aborts**). Each was a credibility kill
   if shipped. Cheap check — list the enclosing `fun` for each cited line and confirm the
   function's actual body:
   ```bash
   awk 'NR>=1500 && NR<=1525 {printf "%d: %s\n",NR,$0}' exchange.move          # read the site
   awk 'NR<=1519 && /(^| )fun /{l=NR": "$0} END{print l}' exchange.move          # enclosing fun
   grep -n "fun verify_liquidation_signature" signature.move && \
     awk '/fun verify_liquidation_signature\(/{f=1} f{print NR": "$0} f&&/^    }/{exit}' signature.move
   ```
   A green PoC proves the *mechanism* works; it does not prove your *prose* about the code
   is accurate. Triagers check citations — a wrong line number reads as "didn't read the code".
