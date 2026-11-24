# Incident response

Speed on containment, discipline on evidence. The two conflict; decide the order explicitly and
write it down.

## Phases

1. **Triage (minutes)** — what is confirmed, what is suspected, what is blast radius. One incident
   commander, one scribe, one channel.
2. **Severity** — data class × spread × business impact. Sev1 gets paging and a war room; Sev3 gets a
   ticket and a watch.
3. **Contain** — isolate, do not power off. A powered-off host loses memory and encryption keys.
   Network-isolate, disable the account, revoke the token, rotate the key.
4. **Preserve** — memory image, disk image, logs, and the timeline, before cleanup.
5. **Eradicate** — remove persistence, patch the entry, rebuild what cannot be trusted.
6. **Recover** — restore from a known-good point, verify, watch for re-entry for 72 h.
7. **Review** — postmortem within five days, blameless, with owners and dates.

## Containment order

| Order | Action | Why |
| --- | --- | --- |
| 1 | Kill the active session/token | cheapest, kills the attacker's access |
| 2 | Isolate the host at the network layer | keeps memory intact |
| 3 | Disable the account, rotate credentials | stops re-entry |
| 4 | Block the C2 at egress | stops the beacon |
| 5 | Snapshot before cleanup | evidence |

## References

| Load | When |
| --- | --- |
| `references/playbooks.md` | per-incident-type steps: ransomware, credential theft, web shell, defacement, insider |

## Evidence

UTC, ISO 8601, hashes, chain of custody. Memory first (`avml`, `winpmem`), then disk (`dd` with a
write blocker). Logs from the SIEM, the proxy, the IdP, and the host, exported immutable. A file with
no hash is not evidence.

## Comms

- Internal: what is confirmed, what is not, what is asked of the reader. No speculation.
- External: legal and comms own the wording; IR supplies the facts and the timeline.
- Customer-facing: what is affected, what they should do, when the next update lands.

## Postmortem shape

```
Summary      3 sentences, no blame
Timeline     UTC, event, source
Root cause   the control that failed, not "human error"
Detections   what fired, what should have
Actions      owner + date, max 6
```

A postmortem with 20 actions executes none. Six, dated, with owners.

## Rules

- Do not power off. Do not `rm` the webshell before imaging.
- Do not reuse the compromised credentials to investigate unless there is no alternative.
- Do not run a full AV scan during the memory capture.
- Preserve the attacker's tooling; a dropped binary is intelligence.
- Assume persistence you have not found. Check scheduled tasks, services, WMI subscriptions, cron,
  `authorized_keys`, and the IdP's OAuth grants.
