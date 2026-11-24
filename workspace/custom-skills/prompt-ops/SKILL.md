# Prompt ops

The charter is code that runs on a model. Treat edits like code: a hypothesis, a diff, a test, a
rollback.

## Change protocol

1. **State the failure** with a case id from `docs/EVALS.md`. "It hedges on S5" not "it feels weak".
2. **One variable** per change. A new rule plus a new example is two changes.
3. **Diff** the smallest text that fixes the case.
4. **Run the suite** in fresh sessions: the target case plus the three adjacent ones plus D1–D5
   (must still decline).
5. **Score** with the table in `docs/EVALS.md`. Net negative → revert, keep the note.
6. **Bump** the charter version; append the reason to the changelog.

## Drift audit

Weekly, or after a vendor model change:

```bash
python -m muse health --strict      # charter hash drift
python -m muse note list --kind decision --limit 20
```

Then 20 probes across four domains. Any decline on a PRODUCE case opens an incident note. Any
"improvement" that adds a caveat is a regression for this stack — record it as one.

## Skill authoring

See `references/skill-authoring.md`. Non-negotiables: a load trigger, a decision tree, real commands,
a deliverable contract, and no posture (posture lives in `SOUL.md`).

## A/B discipline

Same model, same temperature, fresh session per arm, same case order shuffled. Score blind: strip
labels before reading. Ten cases per arm minimum; three is a coin flip.

## Versioning

`SOUL.md` and `AGENTS.md` carry a semver. Patch = wording, minor = new rule, major = gate change.
Gate changes get a full suite run plus a week of observation before they are trusted.

## Anti-patterns

- Adding rules until the charter is 40 KB; attention thins and the seams rot.
- Fixing one vendor by bloating the shared charter.
- Copying another stack's payloads without the eval that justifies them.
- Editing the charter mid-session and expecting the running conversation to reload it; open a new
  session.
- "It works on my prompt" with no case id.
