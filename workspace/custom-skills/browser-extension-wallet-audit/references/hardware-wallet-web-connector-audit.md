# Hardware-Wallet Web Connector Audit (Trezor Connect / Suite web)

Sibling surface to the browser extension: the **web companion + dApp connector**.
For Trezor this is `suite.trezor.io` (Suite web) + `connect.trezor.io` (Trezor
Connect SDK popup). Same audit goal as the extension — page-controlled data reaching
a signing path without an origin/approval gate — but the trust boundary is built
from `window.postMessage` + `BroadcastChannel` + iframe/popup handshakes instead of
content-script↔background IPC.

Program (Aug 2026): direct email `security@satoshilabs.com` (Signal offered for
sensitive), scope = sites at `*.trezor.io` operated by them + devices/software/infra.
Report needs description + impact + **PoC code** + repro. Reward = first valid
submission only (dedup race matters). Out of scope: 3rd-party-hosted (Medium/Twitter/
Cloudflare), DoS, physical/supply-chain, best-practice-only. `.well-known/security.txt`
lives on `trezor.io` (not on the `suite.` subdomain).

## Auditing a giant monorepo without cloning it whole

Trezor Suite is a multi-GB yarn monorepo (`github.com/trezor/trezor-suite`). Never
`git clone` it on a 2GB VPS. Use partial + sparse checkout to pull only the
security-critical packages (final checkout was ~3.7M):

```bash
mkdir ts-audit && cd ts-audit
git init -q
git remote add origin https://github.com/trezor/trezor-suite.git
git config core.sparseCheckout true
cat > .git/info/sparse-checkout <<'EOF'
/packages/connect/src/
/packages/connect-web/src/
/packages/connect-common/src/
/suite-common/connect-popup/src/
/packages/suite/src/support/suite/
EOF
git fetch --depth 1 --filter=blob:none origin develop
git checkout develop
# widen later without re-fetching: edit sparse-checkout, then `git read-tree -mu HEAD`
```

`git ls-tree -r --name-only HEAD | grep -i <keyword>` finds the right paths before you
widen the sparse set. This is faster and lighter than reversing the minified
`suite.trezor.io/web/js/main.*.js` chunks — and since Suite is fully open-source,
source-map spelunking is the wrong path anyway (the map only carries the webpack
runtime bootstrap, not app logic).

## The origin-trust chain (3rd-party dapp → device), layer by layer

```
3rd-party dapp (connect-web)
  → window.postMessage → bootstrap iframe on suite.trezor.io
  → BroadcastChannel(@trezor/connect-popup/{reqId})
  → suite-web popup (useConnectPopupWeb)
  → connectPopupCallThunk → TrezorConnect.call → device
```

Files to read and what each must get right:

| File | Check | Trezor's impl (Aug 2026) |
|---|---|---|
| `connect-common/src/messageChannel/window-window.ts` | inbound `event.origin !== this._origin` AND reject `'null'` | ✅ present, with defensive comment |
| `connect-common/src/messageChannel/abstract.ts` `onMessage` | channel `peer`/`here` string match only — NOT a trust signal | ✅ documented as channel-pairing not auth |
| `connect-web/src/bootstrap/bootstrap.ts` `startForwarding` | `onOwnerMessage` gates on `event.origin !== ownerOrigin`; origin **stamped from real postMessage**, not from `data` | ✅ `broadcast.postMessage({...data, origin: event.origin})` |
| `suite/src/support/suite/useConnectPopupWeb.tsx` | `originRef` starts `'*'` (pre-handshake, no secrets) then narrows to `data.origin` | ✅ origin comes from iframe stamp, BroadcastChannel is same-origin |
| `suite-common/connect-popup/src/permissions.ts` `sanitizeRequestedPermissions` | drop non-grantable, `push_tx` on deeplink, malformed coin **fail-closed** (coin-less = device-wide, never widened) | ✅ |
| `suite-common/connect-popup/src/connectPopupThunks.ts` | hard-block `management`/`internal`/`push_tx`-deeplink before consent | ✅ |
| `connect-web/src/impl/getSuiteWebUrl.ts` | prod always `suite.trezor.io/web/connect-popup`; dev-branch gated to `dev.suite.sldev.cz` | ✅ not reachable from prod |

`getOrigin` (`connect-common/src/utils/urlUtils.ts`) is regex `^https?://[^/]+` — solid.
`corsValidator` (`connectSettings.ts`) allowlists `*.trezor.io`, `localhost:[58]xxx`,
`*.sldev.cz`, `*.onion` — the dev/localhost entries are the only widening and are not
prod-reachable.

## Honest verdict pattern (do NOT inflate)

This code is **post-audit and heavily hardened** — every classic attack (spoofed
channel metadata, `null` origin, origin-narrowing bypass, permission widening) has an
explicit defensive comment saying why it's blocked. Probability of a critical in the
Connect origin layer is low. Recognize this and pivot rather than manufacturing
severity (it dies on triage). Same discipline as the "well-engineered codebase = pivot
after 2h" rule.

## Where residual surface actually lives (leads, HYPOTHESIS-level)

1. **Manifest phishing display** — `parseManifest` (`connectSettings.ts`) only
   `typeof === 'string'` checks `appName`/`appUrl`, both attacker-controlled. If the
   consent modal renders `appName` prominently and the true `origin` faintly, a
   malicious dapp can impersonate a trusted app. Check the consent-modal UI
   (`connect-address-confirmation` / permission modal) for whether origin is shown
   clearly vs obscured. Realistic ceiling: medium(-high), PoC is easy.
2. **Suite CSP `connect-src data: *`** — very permissive. Worth a runtime test for
   whether user-controlled input can drive an outbound fetch (exfil channel). Source
   review alone won't settle it.
3. **Higher-EV pivot** — the freshest funds-affecting surface on a hardware-wallet web
   app is the newer third-party integrations, not the mature Connect core: swap/buy
   (Invity) postMessage/iframe trust + `connect-src *` exfil, and Morpho/Steakhouse
   vault interaction (contract-address pinning, approval-target confusion). Address/
   contract substitution between what Suite renders and what the device signs is the
   real critical class for this target type.

## Reusable checklist for any hardware-wallet web connector

- [ ] Map every `postMessage` / `BroadcastChannel` / iframe hop from dapp to device.
- [ ] For each hop: is the trusted origin taken from `event.origin` (browser-set) or
      from the message body (`data.*`, forgeable)? Body-derived origin = finding.
- [ ] Is `'null'` origin rejected (sandboxed iframe / `file://`)?
- [ ] Permission sanitizer: fail-closed on malformed input, never widen a coin-less
      (device-wide) grant, hard-block management/internal/push-tx paths.
- [ ] Popup URL resolution: can a caller point the popup at a non-prod origin?
- [ ] Manifest fields shown in consent UI: attacker-controlled strings vs the real
      origin — which one dominates the render?
- [ ] Render-vs-sign integrity: does the address/amount shown in the web UI match the
      payload sent to the device (the class that actually loses funds)?
