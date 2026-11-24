# zo-mainnet.n1.xyz — Nord API Leak Notes
Date: 2026-07-25
Target: https://zo-mainnet.n1.xyz

## Findings
- `/admin` returns JSON array of `{"key":"...","roles":["SUPER_ADMIN","FEE_MANAGER","MARKET_MANAGER"]}`
  - These are API keys/tokens, likely scoped to Nord API admin endpoints.
  - If these keys are accepted by `/action` or other endpoints, they may bypass position/account/vault checks.
- `/openapi.json` exposes full service surface.
- `/health` returns detailed component status: execution, history, replica, settlement, oracle.
- `/action` POST accepts `application/octet-stream`: length-prefixed protobuf payload with signature.
- `/ws/trades@{symbol}&deltas@{symbol}&account@{id}&candle@{symbol}:{resolution}` streams trades, deltas, account updates, candles.

## API Surface (from /openapi.json)
- `/markets/live` — live market info (index price, funding rate).
- `/market/{market_id}/live`, `/market/{market_id}/fees/{fee_kind}/{account_id}`, `/market/{market_id}/orderbook`, `/market/{market_id}/stats`.
- `/vaults`, `/vault/{vault_id}`, `/vault/{vault_id}/user/{account_id}`, `/account/{account_id}/vault-user-states`.
- `/account/{account_id}` — account summary (balances, positions, open orders).
- `/account/{account_id}/orders`, `/account/{account_id}/fees/withdrawal`.
- `/account/{account_id}/history/pnl`, `/account/{account_id}/history/position`.
- `/user/{pubkey}` — Solana public key -> account ids + sessions.
- `/timestamp`, `/action/last-executed-id`, `/event/last-acked-nonce`.
- TradingView integraton endpoints: `/tv/config`, `/tv/symbols`, `/tv/history`, `/tv/quotes`.

## Exploitation Notes
- Admin keys from `/admin` may grant elevated access to vault management or fee configuration.
- A malicious key holder could potentially manipulate vault deposit caps, epoch parameters, or fee structures if keys are not scoped.
- `/action` accepting binary protobuf means signature/schema knowledge is required to craft valid admin actions.
- Websocket account stream exposes position history and order lifecycle; sensitive if unauthenticated.

## Next Steps
1. Parse admin key format and test scope against `/action`/`/vault/*`.
2. Check if keys are bound to specific actions or are bearer tokens.
3. If keys are broadly scoped, draft Critical report: "Nord API Admin Key Leak via Public `/admin` Endpoint".
