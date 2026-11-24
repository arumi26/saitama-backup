# Web3 dApp Wallet-Signature Auth Reversal + Non-EVM Node Recon

Chain-agnostic techniques for auditing wallet-auth dApps (EVM or not). Built from the
Zetrix session (Aug 2026) — Zetrix is a **BUMO fork**, ed25519 sigs, `ZTX...` addresses,
NOT EVM. The recon/auth techniques below transfer to any chain that uses wallet-signature login.

---

## 1. Multi-source CT-log subdomain enumeration (NEVER trust a manual list)

**Lesson learned the hard way:** manually probing `app/api/wallet/node/...` found ~6 hosts and
led to a premature "target exhausted" verdict. Pulling CT logs found **41 subdomains**, including
the highest-value apps (`swap`, `multisig`, `tradefi`, `ztrade`, `ebg`, `ebg-admin`) that manual
guessing completely missed. Always run this FIRST, before declaring any surface exhausted.

`crt.sh` frequently returns HTTP 404/502. Do NOT stop there — fan out to multiple sources:

```python
import urllib.request, ssl, json
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
UA = {"User-Agent":"Mozilla/5.0"}
subs = set()

# crt.sh (often flaky — treat failure as normal, keep going)
for url in ["https://crt.sh/?q=%25.TARGET.com&output=json"]:
    try:
        d = json.load(urllib.request.urlopen(urllib.request.Request(url, headers=UA), timeout=45, context=ctx))
        for r in d:
            for x in r.get('name_value','').split('\n'):
                if x.strip().endswith('TARGET.com') and '*' not in x: subs.add(x.strip().lower())
    except Exception as e: print("crt.sh:", e)

# hackertarget (CSV: host,ip)
try:
    t = urllib.request.urlopen(urllib.request.Request("https://api.hackertarget.com/hostsearch/?q=TARGET.com", headers=UA), timeout=30, context=ctx).read().decode()
    for line in t.splitlines():
        h = line.split(',')[0].strip().lower()
        if h.endswith('TARGET.com'): subs.add(h)
except Exception as e: print("hackertarget:", e)

# certspotter
try:
    d = json.load(urllib.request.urlopen(urllib.request.Request("https://api.certspotter.com/v1/issuances?domain=TARGET.com&include_subdomains=true&expand=dns_names", headers=UA), timeout=30, context=ctx))
    for r in d:
        for x in r.get('dns_names',[]):
            if x.endswith('TARGET.com') and '*' not in x: subs.add(x.lower())
except Exception as e: print("certspotter:", e)

print(len(subs)); [print(s) for s in sorted(subs)]
```

Then batch-probe with a threadpool for HTTP status + `Server` header + `<title>`. Prioritize:
`swap*`, `multisig*`, `tradefi*`, `*-admin`, `*-issuer` (dana/privilege), then `502/530/DNS-error`
hosts (broken backends / subdomain-takeover candidates).

---

## 2. Reverse the wallet-signature login flow from the JS bundle

Wallet-auth dApps don't use email/password — login = sign a server nonce with your wallet key.
The whole flow is in the frontend JS. Extract it:

```bash
# 1. Load the SPA, grab JS bundle src(s) (use CloakBrowser if behind Cloudflare)
# 2. Download the main app bundle, grep the auth endpoints + signing sequence:
grep -oE '"/[a-z/]*(login|nonce|token|challenge|verify|session)[a-z/]*"' app.js
grep -oE 'getNonce|createToken|signMessage|signBlob|signData|sendRandom' app.js
```

**Two auth-flow shapes observed on Zetrix (same chain, two backends):**

- **DAO backend** (`/api/zetrix-dao`): `POST /login/before` → `{nonce}` (hex-encoded UUID);
  then `POST /login?username=<nonce>&password=<urlencoded {sign, publicKey}>`.
- **Multisig/wallet backend** (`public-api.zetrix.com`): `GET /token/nonce?address=<addr>` →
  `{nonce}`; wallet does `TextEncoder().encode(nonce)` → hex → signs that hex string;
  then `POST /token {address, publicKey, message, signData}`.

**Read the bundle carefully for the EXACT bytes that get signed.** In multisig the app did:
```js
const i = Array.from(new TextEncoder().encode(e)).map(t=>t.toString(16).padStart(2,"0")).join("");
this.ztx.authorize({method:"sendRandom", param:{random:i}}, ...)  // wallet signs `i` (hex string)
createToken(n /*addr*/, o /*publicKey*/, e /*raw nonce as message*/, i /*signData*/)
```
Note the asymmetry: `message` field = raw nonce, but the signed bytes = hex(utf8(nonce)).

## 3. Generate a controlled keypair + valid signature with the chain's own SDK

You don't need the browser wallet extension. Mint a keypair yourself and sign programmatically:

```bash
# Zetrix/BUMO: node RPC createAccount hands you a full keypair (ed25519)
curl -s https://node.TARGET.com/createAccount   # -> {address, private_key, public_key, sign_type}

# Install the chain's official encryption SDK
npm install zetrix-encryption-nodejs   # exposes keypair, signature.sign/verify
```
```js
const enc = require('zetrix-encryption-nodejs');
const KP = enc.keypair;                       // class
const pub  = KP.getEncPublicKey(priv);        // static derive
const addr = KP.getAddress(pub);
const sig  = enc.signature.sign(msgHexOrText, priv);   // ed25519 -> hex sig
enc.signature.verify(msg, sig, pub);          // roundtrip-check BEFORE hitting the API
```
Always `verify()` your own signature locally first, so a rejected login means *server-side policy*,
not a bad signature.

## 4. THE BLOCKER: signature valid but login still rejected → account must exist on-chain

On Zetrix, every signature-format permutation (raw/hex nonce × sign(raw)/sign(hex)) returned
`"username or password is error"` / `"Invalid signature"` even though local verify was `true`.
Root cause: **the dApp runs on mainnet (chainId 1) and rejects login from an address that does not
yet exist in the ledger.** `getAccount?address=<mine>` → `error_code:4` (not found). A brand-new
keypair isn't activated until it *receives* native token — and the faucet was testnet-only while the
dApp was mainnet. So authenticated audit is gated behind **funding a mainnet account with real money.**

**Rule:** before burning time reversing an auth flow, check whether the target dApp is on mainnet
and whether login requires an *activated* (funded) account. If yes and there's no mainnet faucet,
the authenticated surface is effectively paywalled — factor that into go/no-go early (decision gate).

## 5. Non-EVM blockchain node HTTP API recon (BUMO/Zetrix family)

Public blockchain nodes often expose an HTTP API that mixes safe query endpoints with
management/debug endpoints that should be localhost-only. Enumerate by handler name:

```bash
B=https://node.TARGET.com
for ep in getLedger getAccount getStatus getModulesStatus getConsensusInfo getGenesisAccount \
          getLedgerValidators getTransactionHistory createAccount updateLogLevel debug hello \
          callContract submitTransaction; do
  printf "%-22s " "$ep"; curl -s -m8 "$B/$ep" | head -c 120; echo
done
```
High-signal unauth findings (all Low–Med individually): `/updateLogLevel` (mutates prod node log
verbosity — **note: hitting it is a state change; the program may forbid config changes, so probe
once and stop**), `/createAccount` (server-side privkey generation over HTTP), `/debug` (internal
merkle/hash state), `/getModulesStatus` + `/getConsensusInfo` (infra/consensus info disclosure).
`submitTransaction`/`callContract` requiring signed JSON = correctly gated (no mutation without sig).

## 6. Verdict discipline for these targets

Non-EVM chain dApps with wallet-signature auth are frequently **architecturally sound** at the
layer you can reach unauthenticated: token/signature verification tends to be solid, admin/KYC
endpoints gate on `"please login!"`, Spring `actuator` children (env/heapdump/mappings) are usually
locked, and non-custodial wallets have **no server-side custody to IDOR**. Public surface realistically
yields Low/Med (unauth node mgmt endpoints, verbose error class-name leaks, sequential-ID user
enumeration on `*/open/*` endpoints). Don't inflate these to critical. If the only path to funds-level
bugs is a funded mainnet account and the reward is a low-value native coin, that's a pivot signal.
