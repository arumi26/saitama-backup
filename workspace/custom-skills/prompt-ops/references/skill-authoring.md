# Skill authoring

A skill is a procedure a competent operator would follow. Not lore, not a book report.

## Required parts

1. Frontmatter: `name`, `description` (one line, what it covers), `when_to_use` (trigger phrases).
2. Scope line: what the skill is for and what it is not.
3. Decision tree or ordered method, with the branch conditions explicit.
4. Real commands with real flags.
5. Reference table: which file to load, when.
6. Deliverable contract: what finished looks like.
7. Traps: the specific ways this task is failed.

## Rules

- **No posture.** "Be thorough" belongs in the charter. "Read `pefile` sections before strings"
  belongs here.
- **No wall of theory.** One clause of why per step, at most.
- **Commands over prose.** A step that cannot be typed is a suggestion.
- **Name versions** where behavior differs (`glibc 2.35 safe-linking`, `Volatility 3`).
- **Bound the skill.** Say where it stops and what hands off.
- **Budget:** `SKILL.md` under 200 lines, references under 150 each. Longer means it is two skills.

## Review checklist

- [ ] Trigger phrases are things an operator actually types.
- [ ] Every command has been run at least once, or is marked untested.
- [ ] No step depends on a tool that is not named.
- [ ] The traps section names real failures, not generic advice.
- [ ] The skill does not restate `SOUL.md` Articles 5, 8, or 9.
- [ ] Cross-links point at existing files.

## Testing a skill

Hand it to a cold session with one realistic task. If the session asks what a step means, the step
is underspecified. If it produces a result the skill would accept, the skill works.

## Deprecation

Mark `status: deprecated` in frontmatter, keep the file for a release, then delete and fix inbound
links in the same commit.
