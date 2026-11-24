# Multi-wallet

One mnemonic, many addresses, several chains. The risk is not the crypto — it is index reuse,
nonce collisions, and dust.

## Model

`m/44'/60'/account'/0/index`. Fixed `account` per purpose, monotonic `index`. The vault's
`next_index` guarantees a fresh address; never hand-pick one that already holds value.

| Purpose | account | Note |
| --- | --- | --- |
| treasury | 0 | few addresses, large balances |
| operations | 1 | swaps, LP, gas |
| airdrop | 2 | one address per campaign, never reused |
| test | 3 | throwaway |

## Commands

```bash
python -m muse address --chain base --count 10        # fresh, bumps the index
python -m muse balances --chain base --chain arbitrum --count 10
python -m muse send --chain base --to 0x… --amount 0.01 --index 3 --dry-run
python -m muse sweep --chain base --to 0x… --count 20
```

`send` verifies chain id, simulates, and refuses on insufficient funds before signing anything.

## Funding

Fund from one source, in one batch, to a fixed set. Record the source tx per destination; a
funding graph that fans out from one hot address deanonymizes the set.

Gas budget per address: `gas_limit × max_fee × tx_count` plus 30 %. Underfunded addresses strand
mid-sequence and burn the whole run.

## Nonce

Nonces are per chain and per address. Two processes on one index is a guaranteed collision. Either
serialize, or give each process its own index range.

Stuck tx: broadcast a replacement at the same nonce with a higher `maxPriorityFeePerGas`. Never
send a new tx at the next nonce while the old one is pending — it queues behind.

## Consolidation

Sweep order matters: highest balance first, and reserve `21000 × max_fee` in the last address or it
cannot pay to leave. `sweep` subtracts the fee from the amount for exactly this reason. Sweep dust
last, or let it sit rather than spend more than it is worth.

## Approvals

`eth_call` + `allowance` to audit, `approve(spender, 0)` to revoke, or `increaseAllowance` on
infinite-approval spender. An address that ever touched an unknown contract should not hold the
treasury balance.

## Chain quirks

| Chain | Quirk |
| --- | --- |
| Arbitrum / Optimism / Base | `eth_gasPrice` is an L2 guess; read the L1 data fee component too, and expect `max_fee` to be 1.5–3× the L1-only value |
| Polygon | frequent fee spikes, `POL` not `MATIC`, reorg depth is shallow — wait 30+ confirmations for value |
| BSC | 3 s blocks, `1 gwei` floors, MEV sandwich risk on large swaps |
| Sepolia | no value, use it to rehearse the exact sequence first |

## Airdrop hygiene

- One index per campaign. Never mix a claimed address with an operational one.
- Claim from the address that earned it; forwarding the claim through a fresh address breaks the
  eligibility snapshot in some programs.
- Keep the claim tx hash; some programs require it for support.
- Do not sweep an airdrop address until the claim window closes.

## Privacy

Public RPC providers see `eth_getBalance` and `eth_sendRawTransaction` for your set. A private
endpoint (`--chains-config` with your own node) removes the correlation. Rotating providers by
hand is theater; one provider sees one address set per call batch.

## Routines

**Morning**: `balances` across chains → unstuck nonces → top up addresses under the gas floor.
**Weekly**: prune zero-balance indexes from the working set (keep them in the vault), rotate the
approval audit.
**After a campaign**: sweep to treasury, revoke approvals, archive the index range in `notes`.
