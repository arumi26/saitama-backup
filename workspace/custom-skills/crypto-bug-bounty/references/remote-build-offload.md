# Offloading Heavy Foundry Builds to a Remote Box

## When this applies
The working VPS is 2GB RAM. Some audit targets **cannot compile there** and it is not
fixable by retrying — it is a hardware ceiling:

- **Royco Day** (Cantina): `via_ir = true` + full **Balancer-v3 vault graph** = 487 files.
  `forge build` ran ~2.5h then the kernel `SIGKILL`ed solc (OOM). solc alone hit 40% of
  2GB while swap was already >90% full.
- Any target with `via_ir = true` + a large vendored dependency tree (Balancer, full OZ +
  upgradeable + permit, big monorepos) is a candidate for the same fate.

**Decision rule:** if a build OOMs twice, do NOT keep retrying on the small box. Either
(a) switch to a lighter target, or (b) offload the build to a machine with >=8GB RAM.
PoC-first is mandatory, so "can't build" = "can't PoC" = "can't submit" — resolve the
compute problem before sinking more time.

## Preferred remote-access path: Tailscale (free, no card)
- **ngrok TCP tunnels require a credit card** on the free tier (`ERR_NGROK_8013`) — skip it.
- Tailscale is free, needs no card, gives a **stable `100.x.x.x` IP that never changes**
  (unlike ngrok/cloudflared quick-tunnels), and auto-reconnects when the home box wakes
  from sleep. Best fit for multi-day iterative audit work.

### Installing Tailscale on this Ubuntu (noble) VPS — gotchas
The one-liner `curl … | sudo sh` may time out; the apt path is more reliable but has two traps:
1. The `pkgs.tailscale.com/stable/ubuntu/noble.tailscale-list` endpoint **404s**. Write the
   sources line manually instead:
   ```
   deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu noble main
   ```
   (the `noble.noarmor.gpg` keyring URL DOES return 200 — fetch it to that keyring path.)
2. A pre-existing **broken `google-chrome-stable` package** blocks `apt-get install`
   ("needs to be reinstalled, but I can't find an archive"). Clear it first:
   `sudo dpkg --remove --force-remove-reinstreq google-chrome-stable`, and run
   `sudo dpkg --configure -a` if dpkg was interrupted.

Then: `sudo systemctl enable --now tailscaled` and `sudo tailscale up --authkey=<key> --hostname=hermes-vps`.

### From the user
- User pastes an SSH public key (generate a dedicated ed25519 keypair on the VPS, e.g.
  `~/.ssh/royco_remote`, no passphrase) into their box's `~/.ssh/authorized_keys`.
- User generates a Tailscale **auth key** at login.tailscale.com/admin/settings/keys and
  pastes it in chat so the VPS can join their tailnet. They can revoke it after the box joins.
- Confirm the target box's **username** (`whoami`) before SSHing — don't guess from hostname.

### Verify before connecting
`tailscale status` should list the home box; then `ping -c2 <100.x.ip>` and a TCP-22
reachability check. Only then SSH in, check `free -h` / `df -h`, install Foundry if absent,
clone the repo, and build there.

## Operating the remote box over SSH (gotchas that WILL bite)
Once the box has joined the tailnet and Foundry is installed, the day-to-day audit loop runs
remote. Two traps cost real time:

1. **A login banner / MOTD pollutes every non-interactive command.** Kali's "Selamat datang…
   Tema Cyber-Semarang… TERM environment variable not set" prints on every `ssh host 'cmd'`.
   Filter it out of results with `2>&1 | grep -viE "Selamat|Tema|Waktu|TERM|^$"` so you can
   actually read tool output.
2. **`scp` BREAKS when the shell emits a banner** — `scp: Received message too long 139…` /
   "Ensure the remote shell produces no output for non-interactive sessions." Do NOT fight the
   banner. Transfer files by **piping through ssh's stdin** instead:
   ```bash
   # push a source tree to the remote box, no scp needed:
   tar czf src.tar.gz -C /tmp mysrc
   cat src.tar.gz | ssh -i ~/.ssh/key user@100.x.ip 'cat > /tmp/src.tar.gz && cd /tmp && tar xzf src.tar.gz && echo done'
   ```
   This is banner-proof because `cat > file` swallows stdin verbatim.

**PATH on the remote box:** Foundry (`~/.foundry/bin`) and pip-user tools like slither
(`~/.local/bin`) are NOT on a non-login SSH PATH. Prefix every remote command:
`export PATH="$HOME/.foundry/bin:$HOME/.local/bin:$PATH"`.

**Run the whole PoC loop remotely.** `forge init` (drop `--no-git`/`--no-commit` flags that a
given forge version rejects — just `forge init .`), drop the verified source under `src/`,
match the import layout the contract expects (ExtraFi's `LendingPool.sol` imports
`"../external/…"` + `"../AddressRegistry.sol"` so it must live at `contracts/lendingpool/`,
not repo root), then `forge build` + `forge test`. A 24GB box compiles a 33-file lending tree
+ runs the PoC in seconds where the 2GB VPS OOMs. Slither installs cleanly via
`pip install --user --break-system-packages slither-analyzer` + `solc-select install/use <ver>`.

## Disk hygiene on the small box
The 2GB VPS also runs low on disk (was 96% full). Before/after abandoning a heavy target,
purge its `lib/` + `out/` + `cache/` and stale dead-audit clones to reclaim space. Deleting
many files fast trips the mass-deletion security guard — that's expected, approve it.
