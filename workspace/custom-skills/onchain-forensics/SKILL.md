# On-chain forensics

Public ledger, private inference. The chain proves movement; attribution is a judgment with a
confidence level, and it must be labeled as one.

## First artifacts

| Chain type | Pivot |
| --- | --- |
| EVM | address, first funding tx, nonce pattern, contract deployments |
| UTXO (BTC) | output script types, change heuristic, address reuse |
| Both | exchange deposit addresses, bridge contracts, mixer entries |

Record the block height with every tx hash. A hash alone is not evidence of order; the height is.

## Method

1. **Anchor** — the victim address and the first outbound tx after the incident time.
2. **Follow forward** — one hop at a time, branch by branch. Never skip hops to reach a pretty
   conclusion.
3. **Classify each hop** — CEX deposit, bridge, DEX swap, mixer, contract, personal wallet.
4. **Heuristics** — only with a stated basis: common funding source, identical gas funding, sequential
   nonces from one creator, shared withdrawal address, timing correlation within one block.
5. **Stop conditions** — CEX deposit (subpoena boundary), mixer, or a sanctioned entity.
6. **Confidence** — high (direct tx), medium (two independent heuristics), low (timing alone).

## Tools

`etherscan`/`basescan` API, `blockscout` for L2s, `arkham`, `nansen`, `breadcrumbs`, `metasleuth`.
`dune` for aggregate queries. `chainalysis`/`trm` if licensed. Free tier limits are real; batch and
cache, do not hammer public APIs.

## Sanctions and freezes

OFAC SDN and EU lists include addresses. USDT/USDC issuers freeze on request — a report to the issuer
early can beat the mixer. Check the token contract's `addedBlackList` events.

## References

| Load | When |
| --- | --- |
| `references/tracing.md` | hop-by-hop procedure, heuristic table, bridge and CEX handling, evidence format |

## Evidence bundle

```
case/tx/            one file per hop: hash, chain, height, timestamp, from, to, value, token
case/graph.dot      nodes + labeled edges with confidence
case/labels.md      every attribution with its basis and source
case/README.md      method, limits, chain of custody
```

Hash the bundle. State the block range and the retrieval time. A tracings table without heights is
an anecdote.

## Traps

- Exchange hot wallets look like personal whales; check the label source before calling one.
- Internal transfers (contract calls) are not value movement; read the traces, not just the tx list.
- A bridge hop changes the chain and often the address format — do not assume the same EOA.
- Round-number consolidation is a heuristic, not proof.
- Timezone: chain timestamps are UTC. Say so.
