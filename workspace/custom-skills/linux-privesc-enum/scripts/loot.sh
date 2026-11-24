#!/usr/bin/env bash
# loot.sh — safe, read-only Linux privesc enumeration. Writes a full report + prints a summary.
# Authorized / lab targets only. Does NOT exploit anything.
set -u
HOST="$(hostname 2>/dev/null || echo host)"
TS="$(date +%Y%m%d_%H%M%S)"
OUT="/tmp/loot_${HOST}_${TS}.txt"
sep(){ printf '\n========== %s ==========\n' "$1"; }

{
sep "meta"; id; whoami; hostname; uname -a; cat /etc/os-release 2>/dev/null | head -5
sep "sudo -l"; sudo -n -l 2>&1 || sudo -l 2>&1 || echo "(no sudo / needs password)"
sep "sudo version"; sudo -V 2>/dev/null | head -1
sep "users"; cut -d: -f1 /etc/passwd
sep "groups"; cut -d: -f1 /etc/group
sep "home dirs"; ls -la /home 2>/dev/null
sep "root processes"; ps aux 2>/dev/null | awk '$1=="root"'
sep "listening"; (ss -tulpn 2>/dev/null || netstat -tulpn 2>/dev/null)
sep "crontab system"; cat /etc/crontab 2>/dev/null; ls -la /etc/cron.* 2>/dev/null
sep "crontab user"; crontab -l 2>/dev/null || echo "(none)"
sep "SUID/SGID"; find / -type f \( -perm -u+s -o -perm -g+s \) -exec ls -l {} \; 2>/dev/null
sep "capabilities"; getcap -r / 2>/dev/null
sep "world-writable"; find / -type f -perm -o+w -not -path '*/proc/*' -not -path '*/sys/*' 2>/dev/null | head -60
sep "backups"; find /var /etc /bin /sbin /home /usr/local/bin /usr/local/sbin /usr/bin /tmp -type f \
  \( -name '*backup*' -o -name '*.bak' -o -name '*.bck' -o -name '*.bk' \) 2>/dev/null
sep "db files"; find / \( -name '*.db' -o -name '*.sqlite' -o -name '*.sqlite3' \) 2>/dev/null | head -40
sep "writable /etc files"; find /etc -writable -type f 2>/dev/null
sep "shadow readable?"; ls -l /etc/shadow /etc/passwd 2>/dev/null; head -1 /etc/shadow 2>/dev/null && echo ">>> SHADOW READABLE <<<"
sep "shells"; cat /etc/shells 2>/dev/null
sep "languages"; for b in python python3 perl ruby lua gcc cc g++ node; do command -v $b; done
sep "history hints"; grep -iE '(-p |pass|password|passwd|--pass)' ~/.bash_history 2>/dev/null | head -20
sep "env"; env 2>/dev/null | grep -iE 'pass|key|token|secret|aws|api'
sep "interesting home files"; ls -la ~ 2>/dev/null; find ~ -maxdepth 2 -type f 2>/dev/null | head -40
sep "docker"; id | grep -q docker && echo ">>> user in docker group <<<"; ls -l /var/run/docker.sock 2>/dev/null
sep "mounted fs"; mount 2>/dev/null | grep -vE 'proc|sys|cgroup|tmpfs|devpts|mqueue|shm'
sep "loot tools present"; for t in linpeas.sh LinEnum.sh linux-exploit-suggester.sh; do find / -name "$t" 2>/dev/null; done
} > "$OUT" 2>&1

echo "=============================================="
echo " loot report: $OUT  ($(wc -l < "$OUT") lines)"
echo "=============================================="
echo "--- TOP SIGNALS ---"
grep -m1 -E 'SHADOW READABLE|user in docker group' "$OUT" && echo "  ^^^ immediate escalation path"
awk '/========== sudo -l ==========/{f=1;next} /==========/{f=0} f' "$OUT" | grep -vE '^\s*$' | head -15 | sed 's/^/  sudo: /'
echo "--- SUID (non-standard) ---"
awk '/========== SUID\/SGID/{f=1;next} /==========/{f=0} f' "$OUT" \
  | grep -vE '/(su|sudo|passwd|chsh|chfn|newgrp|gpasswd|mount|umount|pkexec|fusermount|ping|screen|wall|write|expiry|ssh-agent)$' | head -20
echo "--- capabilities ---"
awk '/========== capabilities/{f=1;next} /==========/{f=0} f' "$OUT" | head -15
echo "--- writable /etc ---"
awk '/========== writable \/etc files/{f=1;next} /==========/{f=0} f' "$OUT" | head -15
echo "--- kernel ---"; uname -r
echo
echo "Next: pick the matching exploit from the linux-privesc-enum skill (GTFOBins / searchsploit / docker escape)."
