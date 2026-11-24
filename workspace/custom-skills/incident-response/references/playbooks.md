# Playbooks

## Ransomware

1. Isolate affected segments; keep one domain controller and one backup host isolated but alive.
2. Identify the strain (note file, extension, ransom note) → check for a public decryptor.
3. Preserve one encrypted host whole; image it.
4. Verify backup integrity before restoring; attackers target backups first.
5. Hunt the initial access: VPN logs, RDP, phishing mail, exposed service.
6. Rotate `krbtgt` twice if a DC was touched; reset privileged accounts.
7. Do not pay before checking the decryptor and the exfil site; assume data was stolen.

## Credential theft

1. Revoke sessions and refresh tokens at the IdP, not just the password.
2. Reset the password, then enable MFA if absent.
3. Audit OAuth app grants and mailbox rules for forwarding.
4. Check sign-in logs for impossible travel and new device enrolment.
5. If a password manager was exposed, rotate every vault entry, master password first.

## Web shell

1. Snapshot the host, then copy the shell out for reading.
2. Find the entry: upload endpoint, vulnerable plugin, leaked FTP.
3. Grep the webroot for recent mtime and the same signature; shells come in pairs.
4. Check the parent process of the web user's shell (`www-data` spawning `sh`).
5. Rebuild from a clean image if the shell had write access for long.
6. Rotate DB, API, and cloud credentials read from the host.

## Defacement

1. Preserve the page and the index file with timestamps.
2. Check the CMS version and the admin accounts.
3. Restore from a known-good copy; verify hashes against the repo.
4. Look for a persisted admin, a cron job, or a modified template as the re-entry path.

## Insider / data exfiltration

1. Preserve mailbox, drive, and endpoint logs before notifying the person.
2. Scope by data class and time window; pull the DLP and proxy egress.
3. Legal hold on the device; do not wipe on offboarding.
4. Interview after the evidence is frozen, not before.

## Cloud (AWS/Azure/GCP)

1. Disable the leaked access key / service principal, do not delete it.
2. Pull CloudTrail / Activity Log / Audit Log for the key's window.
3. Check for new IAM users, roles, trust policies, and regions.
4. Snapshot affected volumes and the affected database.
5. Rotate every secret the key could read.

## Comms template (internal, first hour)

```
CONFIRMED: …
SUSPECTED: …
BLAST RADIUS: …
ASKED OF YOU: keep the host on, do not reboot, report odd prompts
NEXT UPDATE: HH:MM UTC
```
