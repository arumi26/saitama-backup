
# EVM Bug-Bounty Toolchain on a Remote VPS

## When to use
- Fresh VPS / audit box needs the full EVM toolchain
- Local box is disk-constrained (prebuilt binaries beat `cargo install`)
- You need to PROVE the toolchain works, not just `--version` it

## Rule zero
`--version` is not proof. Proof = a real vulnerable contract, a real detector hit,
and a real green Foundry PoC. Never report "toolchain ready" from version strings alone.

## Step 1 — Survey before installing
```bash
export SSHPASS='<pass>'
SSHOPT="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=20"
sshpass -e ssh $SSHOPT root@<host> 'whoami; df -h / | tail -1; nproc; free -h | head -2; for t in forge cast anvil slither aderyn echidna solc cargo node python3 git; do printf "%-9s " $t; command -v $t >/dev/null && echo OK || echo MISSING; done'
```
Check disk FIRST. Under ~5G free → use prebuilt binaries only, never `cargo install`.

## Step 2 — Disk cleanup (if tight)
```bash
go clean -cache; rm -rf ~/.cache/pip; find /tmp -maxdepth 1 -mtime +2 -exec rm -rf {} +
```

## Step 3 — Install via prebuilt binaries
Foundry:
```bash
curl -sL https://foundry.paradigm.xyz | bash && /root/.foundry/bin/foundryup
```
Aderyn (x86_64-linux):
```bash
curl -sL -o /tmp/aderyn.tar.xz https://github.com/Cyfrin/aderyn/releases/download/aderyn-v0.6.8/aderyn-x86_64-unknown-linux-gnu.tar.xz
mkdir -p /tmp/adx && tar -xJf /tmp/aderyn.tar.xz -C /tmp/adx
install -m755 /tmp/adx/aderyn-x86_64-unknown-linux-gnu/aderyn /root/.local/bin/aderyn
```
Echidna (x86_64-linux) — plus its mandatory compile dep:
```bash
curl -sL -o /tmp/echidna.tar.gz https://github.com/crytic/echidna/releases/download/v2.3.3/echidna-2.3.3-x86_64-linux.tar.gz
mkdir -p /tmp/ecx && tar -xzf /tmp/echidna.tar.gz -C /tmp/ecx
install -m755 /tmp/ecx/echidna /root/.local/bin/echidna
pipx install crytic-compile          # ECHIDNA FAILS WITHOUT THIS
```
Slither + solc-select:
```bash
pipx install slither-analyzer solc-select
solc-select install 0.8.28 && solc-select use 0.8.28
```
Persist PATH:
```bash
echo 'export PATH="/root/.foundry/bin:/root/.local/bin:$PATH"' >> /root/.bashrc
```

## Step 4 — PROVE IT with a vulnerable demo
Create `/root/bbdemo` with `foundry.toml`, `src/Demo.sol`, `src/Attacker.sol`, `test/Demo.t.sol`.

Critical detail: to make a reentrancy PoC **green on Solidity 0.8**, the victim's decrement
must be `unchecked` (the real-world gas-"optimization" bug). With checked math the unwind
underflows and reverts → `[FAIL: send failed]`, which masks the vulnerability. The `unchecked`
decrement is what makes the drain real:
```solidity
(bool ok, ) = msg.sender.call{value: amt}("");
require(ok, "send failed");
unchecked { bal[msg.sender] -= amt; }   // <- removes the underflow guard
```

Run all three:
```bash
cd /root/bbdemo
echidna src/Demo.sol --contract Demo --config echidna.yaml   # expect "failed!"
aderyn .                                                     # expect report.md, H-* hits
forge install foundry-rs/forge-std
forge test -vv                                               # expect [PASS]
```
Expected green output (attacker 1 ETH in → 5 ETH out, victim insolvent):
```
demo ETH before : 10000000000000000000
demo ETH after  :  6000000000000000000
attacker received: 5000000000000000000
[PASS] test_Reentrancy_DrainsVictimFunds()
```

## Pitfalls
| Symptom | Cause | Fix |
|---|---|---|
| `crytic-compile not installed` | echidna dep missing | `pipx install crytic-compile` |
| `[FAIL: send failed]` | checked-math underflow on unwind | make victim's decrement `unchecked` (realistic) |
| `log_named_decimal_ether` undeclared | not in older forge-std | use `log_named_uint` (wei) |
| `Transaction version (1) not supported` | Solana RPC | `maxSupportedTransactionVersion: 1` |
| install dies mid-build | disk full | prebuilt binaries + cleanup first |

## Operating notes
- Run long installs with `nohup ... > log 2>&1 &`, then poll the log — don't hold the SSH open.
- Foreground SSH calls can exceed the 60s tool timeout; use `timeout=120`+ or background.
- `sshpass -e` + `SSHPASS` env avoids putting the password in argv (visible via `ps`).
- Credentials belong in a `chmod 600` env file, not in memory/plaintext notes.
