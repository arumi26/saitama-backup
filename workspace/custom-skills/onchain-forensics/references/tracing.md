# Tracing procedure

## Per-hop record

```
hash      0x…
chain     base
height    53269811
time      2026-10-30T02:14:09Z
from      0x… (label, confidence)
to        0x… (label, confidence)
value     41.902 ETH
kind      native | erc20:0x… | internal
basis     direct outbound from victim at +00:03:12
```

## Classification

| Class | Signal | Next move |
| --- | --- | --- |
| CEX deposit | labeled hot wallet, memo/tag field, sweep pattern | identify the exchange, request freeze |
| Bridge | known bridge contract, `deposit`/`send` | follow the destination chain by tx hash |
| DEX swap | router call, token transfer in the same tx | follow the output token |
| Mixer | known pool contract, many small outputs | note entry/exit, do not over-claim |
| Contract | `CREATE`, bytecode deploy | check for a withdrawal function and its owner |
| Personal | no label, EOA, low activity | continue |

## Heuristics

| Heuristic | Strength | Caveat |
| --- | --- | --- |
| Direct tx | high | none |
| Common funding source | medium | faucets and CEX withdrawals fund thousands |
| Gas funded from one address | medium | relayers exist |
| Sequential nonce creation | medium | batch deployers exist |
| Same withdrawal address later | medium | shared custody |
| Timing within one block | low | bots and batching |

Two mediums = high. One medium + timing = still medium.

## Bridges

Follow the message, not the address. Take the destination tx hash from the bridge's own event log
(`MessagePassed`, `DepositFinalized`), then trace on the destination chain. Account for the 7-day
optimistic delay on L1 exits; funds can sit in the bridge contract for a week.

## CEX boundary

Identify the exchange from the deposit address label and the memo format. The trace ends at the
deposit; what happens inside is off-chain. Deliver: exchange, deposit address, timestamp, amount,
and the freeze-request template.

## Mixers

Tornado-style pools break the trail by design. Note deposit and withdrawal with the same
denomination, times, and any relayer fee. Do not claim a match without a denomination and timing
correspondence.

## Report limits

Write the paragraph a court would need: what is proven by the chain, what is inferred, and which
hops are unresolved. A confident narrative with a soft middle loses credibility.
