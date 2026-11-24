# Reading Anchor error codes from tx logs

## Where they appear

Solana `simulateTransaction` and `getTransaction` return `meta.err` like:
```json
{"InstructionError": [0, {"Custom": 6039}]}
```
- First element = instruction index in the tx (0-based)
- `Custom: N` = program-specific error code (decimal)

Program logs show hex:
```
Program log: AnchorError thrown in programs/foo/src/instructions/bar.rs:34.
  Error Code: Unauthorized. Error Number: 6039.
  Error Message: Caller is not authorized to perform this action.
Program 4gWM... failed: custom program error: 0x1797
```
- `0x1797 = 6039` decimal — same number, different base

## Code ranges

| Range | Origin | Meaning |
|---|---|---|
| `0 – 99` | Solana runtime | System-level errors (insufficient funds, invalid account, etc.) |
| `100 – 999` | Anchor built-ins | Deserialization, account validation, seed mismatch |
| `1000 – 3999` | Anchor built-ins (extended) | Constraint failures |
| `6000+` (`0x1770`+) | **User-defined** | The program's `#[error_code]` enum |

## Anchor built-ins you'll hit often

| Dec | Hex | Name | Trigger |
|---|---|---|---|
| 100 | 0x64 | InstructionMissing | Wrong dispatch |
| 101 | 0x65 | InstructionFallbackNotFound | Unknown discriminator |
| 102 | 0x66 | InstructionDidNotDeserialize | Args length/types mismatch |
| 143 | 0x8f | AccountDiscriminatorMismatch | Wrong account type passed |
| 2001 | 0x7d1 | ConstraintMut | `#[account(mut)]` violated |
| 2003 | 0x7d3 | ConstraintSigner | Missing signer |
| 2006 | 0x7d6 | ConstraintSeeds | PDA seed mismatch |
| 2012 | 0x7dc | ConstraintOwner | Wrong account owner |
| 3007 | 0xbbf | AccountOwnedByWrongProgram | Cross-check failed |
| 3012 | 0xbc4 | AccountNotInitialized | Read on empty account |

## User-defined codes

Read the IDL's `errors` array. Example:
```json
{"code": 6039, "name": "Unauthorized", "msg": "Caller is not authorized..."}
```

The first user error is always `6000` (`0x1770`). Errors are declared in
source order — the IDL preserves that order. Reading through them gives
you the full list of invariants the developers thought worth checking.

## Attack heuristic

- More errors = more assertions = more attack surface. A program with 100+
  custom errors is *more likely* to have logic bugs than one with 20 —
  each error is a place the developer expected trouble.
- If an error message mentions something like "boundary", "off-by-one",
  "overflow", "underflow", "cycle", "stale", or "race" — that's the dev
  telling you where they were worried. Fuzz there.
- `AccountNotInitialized` (3012) in a spot where the user controls the
  account address is a classic seed-collision / typo-squatting vector.

## Where the log leaks source paths

`AnchorError thrown in programs/<crate>/src/instructions/<file>.rs:<line>` —
this is a free tree map. Collect all these lines from real tx history
via `getSignaturesForAddress` + `getTransaction`, and you have the full
list of instructions actually used in production and their source files.
