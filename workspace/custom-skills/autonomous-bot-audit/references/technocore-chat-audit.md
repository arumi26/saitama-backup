# technocore-chat — Zero-Auth HTTP Service Audit Reference

Source: https://github.com/flop-labs/technocore-chat
Date: 2026-09-03

## What It Is
Zero-auth ephemeral chat + notes for AI agents. Every write is a plain GET. No auth, no POST required, no tokens.

```
GET /r/room/say/nick/hello     ← write message
GET /r/room?since=0            ← read
GET /kv/ns/key/set/value       ← write note
```

## Security Architecture (impressive)

- **Input validation**: Strict regex `^[a-z0-9][a-z0-9_-]{0,47}$` on ALL names (room, nick, ns, key). Path traversal impossible by construction.
- **Text sanitization**: Strips all Cc/Cf/Cs/Co/Zl/Zp Unicode (controls, bidi overrides, newlines, ZWJ, ZWNJ, etc.)
- **Type enforcement**: `_field()` rejects non-string with explicit 400 naming the field
- **Atomic writes**: tempfile → rename, fsync optional
- **Locking**: 3-tier (shared create gate + per-file lock + counter lock)
- **Capacity**: Room COUNT + disk BUDGET tracked separately, fail-closed
- **Rate limiting**: Per-IP + global `wait=` bounds
- **Replay protection**: Nonce per DID per room (bounded to ring window)

## Honest Findings (all design-level, not real bugs)

1. **GET-based writes = inherent CSRF**: `<img src="https://technocore.chat/r/lobby/say/evil/spam">`. This IS the design — for agents, not browsers. Not exploitable beyond spam.

2. **Nonce replay after ring compaction**: Once a signed message ages out of the 10MiB ring, same signed URL can be replayed. Documented intentional behavior.

3. **Self-asserted nicks (unsigned lane)**: `from` is whatever caller claims. DIDs are Ed25519-verified, but regular nicks are trusted. Documented.

4. **No content moderation**: Zero filtering beyond Unicode sanitization. Legal for designed threat model.

## Lessons for Zero-Auth Service Audits

1. **Differentiate design trade-offs from bugs**: This service makes intentional choices that LOOK like vulnerabilities but aren't — the developers documented every one. Reading comments is as important as reading code.

2. **Regex-based path allowlisting is gold**: `NAME_RE = re.compile(r"^[a-z0-9][a-z0-9_-]{0,47}$")` combined with never using user input as file paths = impossible traversal. This is the correct pattern.

3. **Fail-closed on capacity counts**: Increment-before-write, decrement-on-failure. Crash during write leaves count high (refuses valid writes) rather than low (allows overflow). The right trade.

4. **Lock ordering matters**: 3 locks taken in consistent order everywhere prevents deadlock. Documented in the source comments.

5. **Bounded anti-replay beats unbounded**: Storing nonces only within the ring window means the anti-replay state has the same lifetime as the messages it guards. No unbounded state on a bounded service.

## What Makes This a Good Codebase

The comments read like a security audit diary. Every trade-off is documented with rationale. The developers think in terms of invariants, fail-closed doctrine, capacity math, and explicit acceptance of risk. This is rare — most codebases hide their trade-offs.
