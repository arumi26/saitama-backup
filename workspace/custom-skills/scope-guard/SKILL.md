---
skill: scope-guard
title: "Scope Guard — the 5 gates"
category: "Security · Bug-Hunt Core"
load_when: "Phase 00 and before any new host or aggressive action. Non-negotiable."
pack: SUPERAGENT V10
bughunt: true
---
# Scope Guard — the 5 gates
ALL must be TRUE to proceed:
1. **Authorized?** Public program scope / written authorization / owned.
2. **In scope?** Exact asset listed in-scope, not excluded.
3. **Allowed technique?** Not DoS/SE/physical; within automation limits.
4. **Within rate limits?** Honors RoE + killswitch budgets.
5. **Non-destructive?** Prove, don't damage; test accounts, not real victim data.

Any fail → STOP. Do not "just check."

## Hygiene
Isolate (VPN/VM/scoped accounts), tag traffic if asked, keep `../templates/session-log.md`, minimize blast radius, stop at proof.

## Relationship to autonomy
This is the per-action re-check *inside* an engagement. The *field-level* legality check is `../autonomy/authorization-gate.md`. Both must be green.

**→ gates every `../phases/` step and the killswitch (`autonomy/05`).**
