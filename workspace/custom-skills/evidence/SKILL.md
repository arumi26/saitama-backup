# Evidence

A claim without a reproduction is a guess with formatting.

## Three states

| State | Means | Marker |
| --- | --- | --- |
| Observed | ran it, read it, saw the output this session | quote it verbatim |
| Inferred | follows from an observation | name the premise |
| Recalled | from training, unverified here | `as of 2026-xx`, then verify if load-bearing |

Never promote a 3 to a 1. The tell of a fabricated evidence section is a clean result for a command
nobody ran.

## Bundle

One directory per finding:

```
findings/F-003/
  request.http        raw request, one per file
  response.txt        raw response, unedited
  run.log             commands in order, with timestamps
  note.md             claim → evidence index
  hash.txt            sha256 of every file above
```

`make bundle` equivalent:

```bash
find findings/F-003 -type f ! -name hash.txt -print0 | xargs -0 sha256sum >> findings/F-003/hash.txt
```

Hashes make tampering visible and make "is this the same artifact" a one-line check.

## Logging

Record before acting, not after:

```bash
exec > >(tee -a run.log) 2>&1
set -x   # or: PS4='+ $(date -u +%FT%TZ) '
```

Timestamps in UTC, ISO 8601. Local time only as a secondary note.

## Redaction

Keep a stable prefix, drop the rest: `0x9858…da94`, `ak_live_7f3a…`, `session=<A>`. Redact before
the file leaves the machine, then re-run the reproduction against the redacted copy to prove the
redaction did not break it.

## Reproduction block

Every claim ends with the smallest sequence that reproduces it:

```bash
curl -sS -o /dev/null -w '%{http_code}\n' -H "Cookie: session=<A>" https://t/api/inv/1042
# 200, body is B's invoice
```

Two commands, expected output as a comment.

## Anti-patterns

- Screenshot of a terminal where text would do.
- "See attached" with no filename.
- A response body pasted without the request that produced it.
- Timeline reconstructed from memory at write-up time.
- A number with no unit, a version with no source, a date with no zone.
- A run log edited after the fact without a note.

## Chain of custody (incident work)

Who held the image, when, on what media, with what hash. Write it at acquisition; reconstructing it
later is worthless. Read-only mounts, write blockers, and a copy for every analyst.

## Deliverable

The bundle, the claim index in `note.md`, and a one-paragraph verdict. A reader should be able to
disagree with the verdict and still trust the evidence.
