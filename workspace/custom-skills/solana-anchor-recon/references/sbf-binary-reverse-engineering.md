# Stripped SBF/SBPF program reverse engineering (no source)

Use when: a Solana program is deployed + upgradeable but the source is private (no GitHub, no verified
IDL, code-search blocked). You have the `.so` (dumped from ProgramData) and need to audit the logic.
This is the escalation path after recon when there is nothing to read.

## 0. Confirm you hold the LIVE bytecode
Fetch the ProgramData account, base64-decode, strip the ~45-byte metadata header, md5 the payload, and
compare with your local `.so`. Equal md5 ⇒ you are auditing the deployed program, not a stale copy.
(TurboFlow 2026-09: `md5 c5fbe956…` matched → audit is on production bytecode.)

## 1. Toolchain
- `llvm-objdump -d --arch-name=sbf prog.so` — may reject `sbf`; fall back to `bpf`. Gives the disasm.
- **Ghidra with the built-in eBPF processor (`eBPF:LE:64:default`) loads SBF ELF and decompiles it.**
  This is the real unlock — a 688 KB `.so` → ~65 k lines of C pseudocode.
- radare2 default builds usually ship **without** the BPF plugin — check `r2 -L | grep -i bpf` before
  relying on it; don't assume `r2` can disassemble SBF.
- `strings`, `readelf`, `llvm-objdump` come from the distro / Solana toolchain.

## 2. Disasm address scheme — CALIBRATE FIRST
`llvm-objdump` labels are **decimal**, and `byte_offset = label * 8` (one 8-byte SBF slot per label).
Calibrate against a known section: `.text` starts at file offset `0x120` ⇒ label `36` (36×8 = 288 =
0x120). Hexdump to confirm. Getting this wrong silently offsets every jump target and wastes an hour.

## 3. Locate the Anchor dispatch table
Anchor compares the first 8 bytes of ix data to each `sha256("global:<name>")[:8]`. Compute all
candidate discriminators, then scan the disasm for those 8-byte constants appearing back-to-back as
immediates in the dispatcher region (a run of `if (*plVar == <const>)` comparisons). That region maps
discriminator → handler address. TurboFlow: 18 ix at ~`0x52240`, handlers spaced `0x58` apart, each a
thin thunk that tail-calls a large monomorphized body.

**Concrete matching recipe (decompiled-C form).** In the Ghidra `decomp_all.c` the dispatcher reads as
`if (*plVar2 == 0x<hex>) { FUN_ram_<handler>(&local); goto LAB_...; }`. Extract every pair with a
regex, compute the discriminator for each candidate name, and join:
```python
import hashlib, re
def disc(name):  # little-endian int of sha256("global:name")[:8]
    return int.from_bytes(hashlib.sha256(("global:"+name).encode()).digest()[:8], "little")
s = open("disp.txt").read()
for mm in re.finditer(r'\*plVar2 == (0x[0-9a-f]+|-0x[0-9a-f]+)\)\s*\{\s*FUN_ram_([0-9a-f]+)', s):
    uval = int(mm.group(1), 16) & (2**64 - 1)   # <-- see pitfall
    print(f"0x{uval:016x}  {name_for(uval)}  FUN_{mm.group(2)}")
```
- **PITFALL — negated constants.** A discriminator ≥ `0x8000000000000000` is printed by Ghidra as a
  *bitwise-negated* negative literal (e.g. `-0x1a5c70834bf991dc`). You MUST mask `& (2**64 - 1)`
  before comparing, or ~half the instructions silently fail to match. (TurboFlow 2026-09: this is what
  made the first pass look like "only 9 instructions".)
- **Two dispatch entries are Anchor IDL builtins** (`IdlCreateAccount`/`IdlWrite`/…), not project
  instructions — they will not match any `global:` name. Expect N+2 entries for N instructions.
- Candidate names you don't yet know: harvest them first (§3b), don't guess.

## 3b. Recover the FULL instruction enum from Rust debug strings
The single highest-value recovery, and it needs no decompile. Rust panic/debug metadata keeps the
instruction-variant type names in `.rodata`. One grep yields the whole enum:
```bash
strings -n 6 prog.so | grep -oE "[A-Z][A-Za-z0-9]+Instruction" | sort -u
```
Even better, the `Display`/`log` literals are concatenated into one blob you can slice apart:
```
Instruction: InitializeInstruction: GrantRoleInstruction: RevokeRoleInstruction: InitProposeChain…
```
TurboFlow 2026-09: this exposed **18 instructions** when the shipped client IDL only had 11 — including
`GrantRole`, `InitRiskConfig`, `Add/Remove/ApplyWhitelistEntry` — i.e. the entire hidden risk/whitelist
layer, before any handler was read. Also grep `-oE "/[A-Za-z0-9._/-]+\.rs"` for the **source tree**
(`programs/svm-bridge/src/instructions/withdraw/risk_admin.rs` …).

## 4. Extract decompiled functions
- **PITFALL — call-site vs definition.** A naive `re.finditer(r'FUN_ram_NAME\s*\(')` matches the *call
  sites* first (e.g. inside the dispatcher), returning a 3-line stub that looks like a real body. Anchor
  to **definition** lines only: a line starting at **column 0** that carries a return type and ends in
  `NAME(`, then brace-match `{`/`}` to the close. (TurboFlow 2026-09: the first `review_token` "body"
  was 278 bytes of the dispatcher; the real def was 5,395 bytes.)
- **by address:** regex the Ghidra marker `// ==== FUN_ram_000xxxxx @ ram:<addr> (size=N) ====` (note
  the `ram:` prefix). Markers are **not** emitted in address order — sort by address, then take the
  function whose start ≤ target < next function's start.
- **by line:** given a line number (from `grep -n`), walk back to the enclosing `====` marker.

## 5. String xref mapping (Rust SBF specifics)
- Rust `&str` in `.rodata` is **NOT NUL-terminated** — `strings` merges adjacent literals into one long
  blob. To map a literal to code, take the substring **starting at** the literal's address, not the run.
- Ghidra names `.rodata` refs `DAT_ram_0009xxxx` (for this layout `.rodata` vaddr == file offset,
  e.g. base `0x940e8`). Build a map: every `DAT_ram_0009xxxx` → enclosing function. Filtering to the
  project's own range (e.g. `0x945`–`0x94c`) clusters its error/require messages into a few functions.

## 6. Custom error strings = the invariant inventory
```
strings -n 6 prog.so | grep -iE "<word> .{4,}(invalid|must|cannot|already|mismatch|reject|exceed|unauthor|forbidden|paused|expired)"
```
Each project-authored message is a security invariant that EXISTS. Presence ⇒ validation implemented;
a check you *expected* but cannot find anywhere is the lead. TurboFlow custom messages observed:
`Invalid token mint.` · `Invalid receiver.` · `Risk check rejected. reason <bitmap>` ·
`Risk config timelock not expired.` · `Bridge is not active.` · `Invalid amount.`

## 7. FAST falsification before deep RE (do this first)
Cheap, decisive tests that kill or confirm a hypothesis without grinding a handler:
- **Seed-string reference check.** Grep the decompiled body for the **PDA seed literals** the check
  would need. If `review_token` references the `risk_config` seed 3×, the risk check is present →
  the "missing check" hypothesis is dead.
- **IDL account-list comparison.** An ix with 9 accounts and no `risk_config` / `whitelist_entry` /
  `address_freq_stat` accounts physically cannot run that check. Compare `review_token` vs
  `review_token_sol_v1` account lists — the diff tells you which checks are reachable.
- Run these BEFORE the error-string inventory and long before handler-level RE. Two identical failed
  deep-dives = you skipped this step.

## 8. Beyond the binary — the frontend is often the easy win
The bundle that ships the program ID also ships RPC endpoints and dev contacts:
- grep `https://[a-z0-9.-]*(helius-rpc|ankr|quiknode)[a-z0-9.-]*` then POST `getHealth` / `getVersion`
  **unauthenticated** to prove a live leaked endpoint. TurboFlow:
  `hulda-iojerh-fast-mainnet.helius-rpc.com` → `{"result":"ok"}` + `getVersion` ⇒ free access to the
  project's paid RPC quota (LOW–MED: cost/DoS + abuse of a privileged endpoint).
- grep emails `[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}` — leaked personal/dev addresses are PII findings.

## 9. Pitfalls
- **Ghidra headless postScript must be a Java `.java`** in this install (PyGhidra, not Jython). A `.py`
  postScript fails *after* analysis succeeds, so it looks like analysis worked — check the log tail.
- Ghidra does not annotate `.rodata` strings for BPF — resolve them yourself via `DAT_` refs (§5).
- Handlers are large monomorphized Rust; manual RE converges slowly. Prefer §6 + §7 first.
- Ghidra headless on a 688 KB SBF takes minutes — run it **background with notify**, don't block.
- Anchor built-in error names (`ConstraintSeeds`, `AccountDiscriminatorMismatch`, …) also live in the
  blob; don't mistake framework boilerplate for project invariants.
