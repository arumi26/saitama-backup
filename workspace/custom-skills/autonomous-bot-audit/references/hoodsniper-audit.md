# hoodsniper — Reference Audit Case

Source: /tmp/hoodsniper (decrypted zip, Robinhood Chain meme sniper)
Date: 2026-09-03

## Files Audited
| File | LOC | Purpose |
|------|-----|---------|
| config.py | ~200 | All settings, defaults, validation |
| db.py | ~300 | SQLite: positions, calls, sources, decisions, blacklist |
| trader.py | ~250 | Web3 buy/sell (Uniswap V2+V3) |
| engine.py | ~450 | TP/SL monitor, rug detection, agent review loop |
| listener.py | ~120 | Telegram message handler (userbot, event.NewMessage) |
| dexscreener.py | ~60 | Dexscreener API (pair, mcap, liq, price) |
| safety.py | ~100 | Blockscout: dev holding %, top-10 holder % |
| agent.py | ~250 | LLM layer (Claude/OpenAI) — entry + manager + coach |
| control_bot.py | ~250 | BotFather inline keyboard control panel |

## Key Findings (all design-level, not exploit-ready)

1. **Stale price oracle**: Dexscreener = off-chain. mcap/liq/priceNative all from API. No on-chain verification. A flash-loan price spike on Dexscreener → bot buys rug.

2. **Honeypot check limitations**: `_can_sell()` uses eth_staticCall before buy. Post-buy activation honeypots bypass this. Mitigated by sim-sell check after buy.

3. **V3 slippage edge case**: If `priceNative=0` on pair → `expected=0` → `min_out=0` → no slippage protection.

4. **Fail-open data sources**: Blockscout timeout = configurable. Default is fail-closed, but operator can set fail-open. Dexscreener timeout = skip (safe).

5. **No MEV protection**: Direct `eth_sendRawTransaction` — front-runnable on any chain with public mempool.

6. **Self-asserted identity**: Telegram `sender_id` = identity. No signature verification. Anyone with group access can post fake calls if they control the account.

7. **No monitoring**: No balance threshold alert. If bot wallet drained, only discovered on next buy attempt.

## Hardening Recommendations

1. **On-chain price check**: After Dexscreener filter, verify `getAmountsOut` on-router before buy commit
2. **min_out floor**: clamp `min_out >= expected * 0.5` even when priceNative=0
3. **MEV protection**: Use Flashbots/private RPC or add deadline + private tx
4. **Balance monitoring**: Alert if wallet balance drops below threshold without trade
5. **Caller identity hardening**: For groups where integrity matters, require signed call verification

## Design Strengths

- Fail-closed safety by default (configurable)
- LLM output clamped: size_mult, TP/SL all bounded
- Triple-layer exit: deterministic TP/SL + LLM review + manual sell buttons
- Blacklist caller with proven track-record analysis
- Coach module proposes settings changes conservatively
- Dedupe: `seen_call()` prevents same CA double-buy
