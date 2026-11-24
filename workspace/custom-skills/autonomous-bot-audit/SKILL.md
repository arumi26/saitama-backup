
# Autonomous Agent Source Audit

Audit a downloaded autonomous agent — Python bot (Telegram userbot, sniper, trading bot, stealer) or Node/TypeScript agent runtime — and produce a structured risk report with exploit paths.

Pick the language lane, then follow it:
- **Python bots** → the workflow below (steps 1-5).
- **Node/TypeScript agent runtimes** (plugin/skill systems, `node:vm` sandboxes, CLI-keychain signers, A2A bridges) → "Node/TypeScript Agent Runtime Audit" below, plus `references/node-agent-runtime-audit.md` for the full surface map and `scripts/ssrf-guard-probe.ts` for the re-runnable SSRF guard battery.

## Workflow

### 1. Extract & Orient

```bash
# If zip/tar
cd /tmp/bot-audit && unzip -o bot.zip
# If GitHub — FALLBACK WHEN web_extract BLOCKED (always git clone for repos)
git clone --depth 1 https://github.com/org/repo.git reponame
ls -la
```

Identify: framework (telethon/pyrogram/aiogram), target chain, language, fund flow.

### 2. Read Core Files First

Read only 3-4 files to understand the bot in one pass:

| File | Tells you |
|------|-----------|
| `config.py` | ALL settings, thresholds, API keys, chains |
| `trader.py` / `engine.py` | External calls, swap logic, fund movement |
| `listener.py` / `main.py` | Entry point, message handling, triggers |
| `agent.py` (if present) | LLM layer boundaries and clamp logic |

Skip `__init__.py`, `requirements.txt`, tests on first pass.

### 3. Map Attack Surface

Per core file, note:
- **External calls**: every requests.get/post, w3.eth.call, trader.buy/sell
- **User-controlled inputs**: what can an attacker influence via messages, API responses, env?
- **Trust boundaries**: where does untrusted data enter trusted operations?
- **Financial flows**: balance read → decision → swap/send sequence

### 4. Check These Patterns

```
□ Stale price oracle (off-chain API = manipulatable)
□ Honeypot check bypass (static-call misses post-buy activation)
□ V3 min_out=0 when priceNative=0 (division by zero)
□ Data source timeout = fail-open vs fail-closed
□ No MEV protection on swaps (front-running)
□ Fail-open safety defaults (data unavailable → trade anyway)
□ Self-asserted identity (nick not enforced)
□ Replay/nonce reuse (bounded window, aged-out nonces replayed)
□ Auth absence (zero-auth writes = CSRF by design)
□ Hardcoded secrets or API keys in config
□ Unsafe deserialization (pickle, yaml.load, eval)
□ Path traversal (file reads from user input, no allowlist)
□ SQL injection (raw queries with f-strings)
□ Command injection (subprocess/os.system with user input)
□ SSRF (requests to user-controlled URLs)
□ Unvalidated callback (webhook with no signature check)
□ Sybil / incentive-fraud intent (multi-wallet gen, captcha-solver deps, proxy rotation)
```

### 5. Output Structure

```
## Bot Overview
## Data Flow (sequence diagram style)
## Critical Findings (file:line, root cause, exploit path, severity)
## Architecture Risks (centralization, fail-open, no monitoring)
## Honest Assessment (exploitable vs theoretical vs design trade-off)
```

## Node/TypeScript Agent Runtime Audit

For agent frameworks (openclaw / xpr-agents-style): a `src/` core + `skills/*/src/index.ts` plugins + a `starter/` runner + a `create-*` scaffolder. Five surfaces, in priority order — audit them in this order because the first two are where real findings live.

### 1. SSRF guard — is it bypassable, and is it applied everywhere?

Run `scripts/ssrf-guard-probe.ts` against the guard module (usually `skills/*/src/ssrf.ts`, export `assertPublicUrl`). It fires the full encoding battery and prints the host normalization the guard actually sees.

What a *correct* guard looks like (verified good in the wild):
- Parses with `new URL(url)` and **re-checks the parsed hostname**, not the raw input string.
- Handles IPv4 in all encodings — decimal (`2130706433`), octal (`0177.0.0.1`), hex (`0x7f000001`), short (`127.1`) — because it resolves via `dns.lookup()` and checks the **resolved** address.
- Blocks wildcard-DNS-to-private (`127.0.0.1.nip.io`), `localhost`, `169.254.169.254` (cloud metadata).
- **Fails closed**: a host that does not resolve is *denied*, not allowed.

The two things worth actually verifying, because they are where this class of guard really breaks:
1. **Every outbound call routes through the guard.** Grep every `fetch(` / `axios(` / `http.get(` site in the whole tree and confirm each one passes through the guard. A guard that exists in one helper but is bypassed by a direct `fetch()` elsewhere is the finding — not the encoding trivia.
2. **Guard ordering.** Deny-by-default on resolution failure. If an unresolvable host is treated as allow, that's the bug.

Don't report encoding bypasses from theory — see Pitfalls.

### 2. `node:vm` sandbox — check both escape paths

A sandboxed JS tool (`skills/code-sandbox/`) is escaped by one of exactly two things:

| Escape path | Why it works | Required fix |
|---|---|---|
| `vm.createContext(hostObject)` | The sandbox global inherits the **HOST** realm's `Object.prototype`, so `this.constructor.constructor("return process.env")()` walks to the host `Function` | Pass a **null-prototype** global: `Object.create(null)` |
| Any host function/closure handed into the realm (console mock, `Buffer`-backed `atob`, host `JSON.stringify`) | `fn.constructor` is the **host** realm's `Function`. `codeGeneration:{strings:false}` only disables codegen for the sandbox's *own* realm | Implement console/atob/btoa/input-parse/**result-serialization** as sandbox-realm JS (a preamble string); cross only primitive strings in, read back only a JSON string |

Also verify: result serialization happens **inside** the sandbox (a hostile getter can otherwise stall the host through a host-side `JSON.stringify`), and the execution timeout actually wraps it. Only a JSON string may come back out.

### 3. Command execution — sweep, then triage false positives

```bash
grep -rn "child_process\|execSync\|exec(\|spawn(\|spawnSync\|execFile" <scope> | grep -v "\.d\.ts"
```
Triage every hit. **`RegExp.prototype.exec` and `regex.exec(text)` match `exec(`** — in practice most or all hits are regex, not shell. The safe pattern is `execFileAsync('bin', [args], {timeout, maxBuffer})` with an **array** (no shell → no injection even with user-influenced args). The anti-pattern is `exec(\`cmd ${userInput}\`)`. Confirm a timeout and `maxBuffer` are set.

### 4. Tool-mode / authorization classification

If the runtime has a read-only vs write tool mode (e.g. `A2A_TOOL_MODE=readonly`, an `a2a-tools` RO/RW split), audit it **by classification, not by tool name**: enumerate registered tools, and for each tool labelled read-only, grep its handler body for write indicators (`transact|sign|send|write|create|update|delete|post`). A read-only-labelled tool whose handler reaches a `transact`/sign call is a privilege escalation past the mode flag. Report file:line.

### 5. Signer / key boundary

Preferred design: the agent process **never holds a private key**; signing shells out to a CLI keychain (`proton key:add` → encrypted keychain), and the legacy `*_PRIVATE_KEY` env var is explicitly refused at startup. Verify:
- No private key is read from env or config anywhere in the process.
- Stderr is scrubbed before logging (`data` / `hex_data` blocks stripped) so memos and payloads don't leak into logs.
- The account permission model: `owner` should delegate to a human-controlled account with **no raw keys**, so a leaked `active` key cannot rotate the account away from the owner (a `setup-security.sh`-style lockdown).

## Triage Protocol

Kill the finding if:
- Requires owning a cloud API provider — cannot prove
- Documented trade-off by developer
- Vulnerability IS the bot's core design
- Impact is "could theoretically" with no fund-loss path

## Pitfalls

- Don't inflate severity: stale oracle ≠ rug pull
- Don't scan for CVEs: this is custom bot code, not a framework
- Don't fabricate impact: only claim fund-loss paths traceable through code
- **Git clone is mandatory fallback**: web_extract/web_search are blocked for GitHub — always `git clone --depth 1` for repos
- **Classify intent before hunting bugs**: if the bot's purpose is incentive fraud — an N-wallet farm + CAPTCHA bypass (`DrissionPage` / `speech_recognition` / `pydub` audio-challenge solver) + per-wallet proxy rotation — then the finding is the *purpose*, not a code defect. Do not complete the missing pieces and do not run it. Report the classification and offer (a) single-account legit use or (b) an audit of the target protocol's on-chain code. Full disposition: `testnet-quest-bots` → "Sybil-Farm & CAPTCHA-Bypass Boundary".
- **Don't claim an SSRF/encoding bypass from theory — verify against the target's own parser and resolver.** The WHATWG URL parser normalizes IPv6 to canonical form before a guard sees it (`new URL('http://[0:0:0:0:0:ffff:127.0.0.1]/').hostname` → `[::ffff:7f00:1]`), and Node's `dns.lookup()` itself resolves decimal/octal/hex literals (`2130706433`, `0177.0.0.1`, `0x7f000001`, `127.1`) to dotted-quad. So expanded-form and exotic-literal bypasses often collapse to a form the guard already blocks. Prove reachability with a runnable probe before writing it up — a "bypass" that the guard blocks is a false positive that costs credibility. Working probe: `scripts/ssrf-guard-probe.ts`.
- **A guard that isn't applied on every outbound call is the finding, not the guard's parsing.** Before hunting encoding tricks, grep every `fetch(`/`axios(` site and confirm each routes through the guard.
- **`exec(` grep hits are usually regex.** `RegExp.prototype.exec` / `regex.exec(text)` match a command-injection sweep. Triage each hit before reporting; `execFile` with an args array is not injectable.
