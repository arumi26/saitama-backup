# Node/TypeScript Agent Runtime Audit — openclaw / xpr-agents (XPR Network)

Worked audit of `XPRNetwork/xpr-agents` (the `openclaw` agent framework), as a concrete
template for this class. Layout:

```
openclaw/
  src/                     core: proton-cli.ts (signer), session.ts, cli-session.ts, tools/*
  skills/*/src/index.ts    plugins: code-sandbox, web-scraping, tax, nft, blockart, creative, smart-contracts…
  starter/agent/src/       runner: index.ts, a2a-tools.ts, a2a-auth.ts, scan-guard.ts, security.ts, skill-loader.ts
  starter/telegram/src/
create-xpr-agent/          scaffolder: create.mjs + template/{start.sh,setup-security.sh,.env.example}
```

---

## 1. SSRF guard — `skills/web-scraping/src/ssrf.ts` (`assertPublicUrl`)

Empirical battery result (run with `node --experimental-strip-types`, Node 6.8 kernel / modern Node):

| Input | Result |
|---|---|
| `http://127.0.0.1/` | blocked — private address |
| `http://127.1/` | blocked — private address |
| `http://2130706433/` (decimal) | blocked — private address |
| `http://0177.0.0.1/` (octal) | blocked — private address |
| `http://0x7f000001/` (hex) | blocked — private address |
| `http://127.0.0.1.nip.io/` (wildcard DNS) | blocked — host resolving to a private address |
| `http://localhost/` | blocked — host resolving to a private address |
| `http://169.254.169.254/` (cloud metadata) | blocked — private address |
| `http://[::1]/` | blocked — **host that does not resolve** |
| `http://[::7f00:1]/` | blocked — host that does not resolve |
| `http://[::ffff:127.0.0.1]/` | blocked — host that does not resolve |
| `http://[0:0:0:0:0:ffff:7f00:1]/` (expanded) | blocked — host that does not resolve |
| `http://[0:0:0:0:0:0:0:1]/` (expanded loopback) | blocked — host that does not resolve |
| `http://[64:ff9b::7f00:1]/` (NAT64) | blocked — host that does not resolve |
| `http://spoofed.example.com/` | blocked — host that does not resolve |

**Verdict: no bypass.** Two independent reasons the exotic forms are unreachable:

1. **The URL parser normalizes first.** `new URL('http://[0:0:0:0:0:ffff:127.0.0.1]/').hostname`
   returns `[::ffff:7f00:1]` — expanded IPv6 is compressed to canonical form before the guard
   inspects it, so `0:0:0:0:0:ffff:…` and `0:0:0:0:0:0:0:1` are just the forms the guard already
   handles. (Note the *literal string* `0:0:0:0:0:ffff:127.0.0.1` fails a naive `isIP()` check —
   `isIP()` returns 0 for it — which is exactly why parsing via `new URL()` first is the correct
   design. A guard that ran `isIP(rawInput)` instead would miss it.)
2. **The resolver normalizes too.** Node `dns.lookup()` resolves the exotic IPv4 literals:
   `2130706433` → `127.0.0.1`, `0177.0.0.1` → `127.0.0.1`, `0x7f000001` → `127.0.0.1`,
   `127.1` → `127.0.0.1`. So a guard that resolves and then checks the *resolved* address catches
   them without any explicit literal parsing.

The IPv6 rows are blocked by the **"does not resolve" (fail-closed)** branch. That is the branch to
verify in any guard: if unresolvable hosts are allowed instead of denied, the whole thing collapses.

## 2. `node:vm` sandbox — `skills/code-sandbox/src/index.ts`

Two tools, `execute_js` and `eval_expression`, both funnelling through `runInSandbox()`. The
implementation is **correct and worth using as the reference pattern**:

- Global is `Object.create(null)` → null prototype. Comment in-file records a confirmed escape
  via the global-object path (`this.constructor.constructor("return process.env")()`) before this
  fix, 2026-09-19.
- `vm.createContext(sandboxGlobal, { codeGeneration: { strings: false, wasm: false } })`.
- **Only primitive strings cross in.** `__INPUT_JSON` is a string; the sandbox does its own
  `JSON.parse`.
- `console`, `atob`, `btoa`, `INPUT` are all defined by `SANDBOX_PREAMBLE` — pure sandbox-realm JS
  source injected into the wrapped script. No host closure is ever handed in, so there is no
  `fn.constructor` to walk to the host realm.
- **Result serialization runs inside the sandbox** (`JSON.stringify({ok, result, logs, error})`
  evaluated in-realm) — so a malicious getter on `result` can't stall the host through a host-side
  `JSON.stringify`, and it stays under the execution timeout. The host only receives a JSON string,
  checks the 10MB cap, and parses it.
- `codeGeneration.strings:false` means `eval`/`Function` are blocked *in-realm* — the handler maps
  "Code generation from strings disallowed" to a friendly error, which is the expected UX.

Audit checklist for any similar sandbox: null-proto global? any host function/object crossing in?
who serializes the result? does the timeout wrap serialization? is only a primitive read back?

## 3. Command execution — clean

Sweep across `openclaw/skills/*/src/*.ts`, `openclaw/starter/agent/src/*.ts`, `create-xpr-agent`:

```
child_process | execSync | exec( | spawn( | spawnSync | execFile
```

All hits were `RegExp.prototype.exec` / `regex.exec(text)` (blockart ×3, creative, web-scraping).
**No shell execution anywhere.** The only real process spawn is `src/proton-cli.ts`, which uses
`execFileAsync('proton', args, { timeout: 30_000, maxBuffer: 10MB })` — an **array** of args, no
shell, so no injection even for user-influenced values.

## 4. Tool-mode classification

Runtime has `A2A_TOOL_MODE=readonly` (default, seeded in `start.sh` / `.env.example`) with a RO/RW
split in `starter/agent/src/a2a-tools.ts`. Classification audit — "RO-classified tools whose handler
body contains a write indicator":

```
RO-classified tools whose handler body contains a write indicator: 1
  sc_get_action_history  skills/smart-contracts/src/index.ts:313  ->  transact
```

One read-only-labelled tool whose handler references `transact`. This is the shape of finding the
mode-flag audit produces: the name says read-only, the body reaches a signing path. Triage it
against the actual call (is `transact` reached on the RO path, or is it dead/guarded code?) before
reporting severity.

## 5. Signer / key boundary — sound

- `start.sh` **refuses** `XPR_PRIVATE_KEY` in env with a migration message; the script header states
  "This script does NOT take a private key. All signing is done by the proton CLI." The agent process
  never reads a private key.
- `--key` CLI flag was removed and errors out pointing at the keychain flow.
- `src/proton-cli.ts` `scrubStderr()` strips `"data": {…}` and `"hex_data": "…"` blocks before
  logging, so memos/addresses don't land in logs. Errors are classified
  (`network|auth|serialization|reverted|unknown`) by stderr signature.
- `setup-security.sh` implements the Pillar-2 lockdown: delegate `owner` to a human-controlled
  account with no raw keys so a leaked `active` key can't rotate the account. It requires a TTY
  (refuses pipes/automation), type-to-confirm both account names, and re-fetches end state to verify
  the change landed. Good pattern to point other projects at.
- Startup diagnostic in `start.sh` detects owner-with-raw-keys and recommends the lockdown —
  non-blocking.

## Notes on the scaffolder

`create-xpr-agent/create.mjs` uses `cpSync` + a recursive chmod of `.sh` files. It prints the
keychain setup steps including the hosted-console workaround
(`echo "no" | proton key:add PVT_K1_…`). No injection surface — args are only used as a target
directory via `resolve()`.

## Disposition

No critical findings. The SSRF guard, the `node:vm` sandbox, the `execFile`-only process boundary,
and the keychain signer design are all correct. The one flagged item is the RO-tool/`transact`
classification hit in `sc_get_action_history` — verify reachability before reporting.
