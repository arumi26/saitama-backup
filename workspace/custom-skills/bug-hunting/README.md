<p align="center">
  <img src="banner.png" alt="Bug Hunting — bug bounty, penetration testing, AI powered" width="100%">
</p>

<p align="center">
  <a href="https://github.com/m4vic/bug-hunting/stargazers"><img src="https://img.shields.io/github/stars/m4vic/bug-hunting?style=flat-square&color=e11d48" alt="GitHub stars"></a>
  <a href="https://github.com/m4vic/bug-hunting/releases"><img src="https://img.shields.io/badge/version-1.0.0-e11d48?style=flat-square" alt="Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-e11d48?style=flat-square" alt="License: MIT"></a>
  <a href="https://github.com/m4vic/bug-hunting/network/members"><img src="https://img.shields.io/github/forks/m4vic/bug-hunting?style=flat-square&color=e11d48" alt="GitHub forks"></a>
</p>

# Bug Hunting Skill

**Bug bounty hunting & penetration testing skills for Claude, Codex, and any agentic coding tool.**

A signal-driven, structured skill package that turns a general-purpose coding agent into a disciplined web/API/mobile/cloud/AI-LLM vulnerability hunter — not by dumping a wall of technique text into context, but by routing to only what's relevant, and by making the agent actually *operate* like a hunter (working folders, hypothesis tracking, confirm-before-report), not just recite vuln classes.

---

## What this is

Most "hacking skill" packs for AI agents are a single giant file, or dozens of files, each 300–500+ lines, loaded all at once regardless of relevance — heavy on payout tables and named bug-bounty programs, thin on the actual decision logic a hunter needs mid-recon. That's expensive on tokens and worse, it drowns the model in procedure instead of teaching it how to *think*.

This skill is built the opposite way: a tiny router at the top, six domain-specific signal tables underneath, and 70+ compact technique references that only load when a signal table actually points at them. Nothing loads until it's needed.

## What it consists of

```
bug-hunting/
  SKILL.md                    <- entry point. Routes by target type. ~50 lines.
  methodology/
    workflow.md                 <- the operating discipline (see below) — run first
    mindset.md                   <- map-wide / hypothesize-wide / confirm-strict loop
    reporting.md                  <- how to write up a finding that gets paid, not closed
  web/            ROUTER.md + references/   (34 vuln classes + 6 framework fingerprints)
  api/            ROUTER.md + references/   (GraphQL, gRPC, WebSocket, shadow APIs, ...)
  mobile/         ROUTER.md + references/   (Android, iOS, thick-client reversing)
  cloud-identity/ ROUTER.md + references/   (cloud/K8s/CI-CD, SAML/Okta/Entra/LDAP/VPN)
  ai-llm/         ROUTER.md + references/   (prompt injection, jailbreak, RAG poisoning, agent/tool abuse)
  recon/          ROUTER.md + references/   (subdomain enum, OSINT, secrets, source leaks)
```

**79 markdown files total.** Every `ROUTER.md` is a signal table: *observable thing about this target → plausible vuln class(es) → one-line confirmation test → which reference file to open for depth.* Every `references/*.md` is a compact, technique-dense distillation — real payloads, real bypasses, real exploit chains — with the payout-table and named-program filler stripped out.

## How it's meant to be used

1. Point the agent at a target. It loads `SKILL.md` (a few hundred tokens), which sends it to `methodology/workflow.md` first — not a vuln class.
2. `workflow.md` has it set up a **real per-target working folder** (`scope.md`, `recon/`, `hypothesis-log.md`, `findings/`, `session-notes.md`) before a single request goes out, and gates it from jumping to exploitation before recon is actually marked done.
3. Based on what the target looks like (web app, API, mobile app, cloud/identity surface, AI/LLM feature), `SKILL.md` routes to exactly one domain `ROUTER.md`.
4. The router's signal table points at plausible classes; only the matching `references/*.md` file loads for depth — not the other 78.
5. Every hypothesis tried, confirmed, or refuted gets logged, so a long session never re-tests the same thing twice.
6. A finding only becomes a report once it clears `methodology/reporting.md`'s validation bar — reproduced, in scope, evidence captured.

That loop — map wide, hypothesize wide, confirm strict, track everything, report only what's proven — is the actual discipline that separates hunters who find real bugs from people who know the same techniques but don't systematize them. Most skill packs teach the techniques and skip this; this one leads with it.

## Who this is for

- **Bug bounty hunters and pentesters** using Claude Code, Codex, or any agentic tool as a hands-on research assistant on an authorized target.
- **Security tool builders** who want a structured, signal-driven technique reference to encode into their own scanners, mappers, or exploit modules — the signal tables are designed to be directly translatable into rule-based or LLM-driven attack-mapping logic.
- **Anyone learning offensive web/API/mobile/cloud/AI security** who wants a reference organized the way a working hunter actually uses one — by observable signal, not alphabetically by CVE.

## Compatibility

**Not Claude-only.** Every file in this skill is plain, self-contained markdown — no Claude API calls, no Anthropic-specific syntax, nothing tool-locked anywhere in the actual content. The one Claude Code–specific piece is `SKILL.md`'s YAML frontmatter (`name:` / `description:`), which is a Claude Code *auto-discovery* convention — it's what lets Claude Code find and load this skill on its own, without being told to.

That means the difference between tools is **auto-discovery vs. manual pointing**, not compatibility:

- **Claude Code** — drop `bug-hunting/` into your skills directory; the frontmatter makes it auto-discoverable, no manual pointing needed.
- **Codex, Antigravity, Cursor, or any other agentic coding tool** — these don't recognize the `SKILL.md` auto-discovery convention, but that's a discovery mechanism, not a content restriction: just point the agent at `bug-hunting/SKILL.md` directly ("read this and follow it") or hand it the relevant domain `ROUTER.md` for the engagement at hand, and it works identically — everything past the frontmatter is ordinary markdown any agent can read and reason over.
- **A standalone human reference** — every file reads fine on its own in a browser or editor, frontmatter and all.

## Scope and legal

This skill assumes **authorized testing only** — an in-scope bug-bounty program you've read the rules for, your own systems, or a lab you control. `SKILL.md` states this explicitly and every workflow step checks against a written `scope.md` before acting. Nothing here is a substitute for reading the actual program rules of whatever you're testing.

## Status

Built by compressing and restructuring a larger, less organized technique-file collection into this signal-first shape. Reference content is dense but not exhaustive — if you find a gap, extend the matching domain's `ROUTER.md` and add a `references/` file the same way the existing ones are structured (signal table entry → short technique file, no payout tables, no filler).

## License

[MIT](LICENSE) — use it, fork it, adapt it, commercial or not. Just keep the copyright notice.
