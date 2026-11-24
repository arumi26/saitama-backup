
# Payment Gateway / Callback Authenticity Audit

Hunt the highest-severity web2 class in payment integrations: **the callback/IPN/webhook handler
does not verify the provider's signature**, so an attacker forges a "payment succeeded" callback and
the platform marks the order/invoice paid. No MITM, no API key, no valid signature — just one
unauthenticated HTTP request to a public callback URL.

This is the *strongest* form of the bug. If you can only show a TLS/MITM dependency (plaintext
callback URL, api_key intercepted in transit), keep hunting — a missing-signature-check finding
usually exists in the same family and needs no on-path position.

## The bug class (why it matters)

- **CWE-345** Insufficient Verification of Data Authenticity / **CWE-306** Missing Authentication for Critical Function.
- Attacker registers as a client (or just guesses a `client_id` + sequential invoice/order IDs) and
  POSTs a forged callback with `status=completed` → platform records `approved` → **invoices marked PAID**.
- Business impact is far above the raw CVSS. Signature bypass scores honestly as
  `AV:N/AC:L/PR:N/UI:N/S:U/C:N/I:H/A:N` ≈ **8.2** (integrity-only, no confidentiality/availability),
  but for a payment gateway it is practically **critical**: a customer frees their own invoices for free.
  Report the real impact; do not inflate CVSS.

## Step 0 — Recon: locate the callback entry point

Clone the plugin repo(s). The entry point is the method the framework calls when the provider hits
the callback URL. Read *only that method* first — that's where authenticity must be enforced.

| Framework | Callback entry point | Required check |
|---|---|---|
| Blesta (non-merchant gateway) | `validate(array $get, array $post)` | verify HMAC **inside** `validate()` before returning `'status' => 'approved'` |
| WooCommerce gateway | `webhook()` / `process_webhook()` / `check_ipn_response()` | official gateways call `validate_ipn()` |
| Easy Digital Downloads | `edd_process_webhook` / gateway callback fn | hash compare before fulfilling |
| OpenCart | `catalog/controller/payment/<gw>.php::callback()` | HMAC compare |
| PrestaShop | `controllers/front/callback.php::postProcess()` | `Tools::hash` / `hash_equals` |
| WHMCS / Magento / generic | module callback controller | HMAC verify |

## Step 1 — Find the verifier, detect dead code  ⭐ the killer technique

Signature verifiers are often **present but never invoked**. Grep for the verifier's name and exclude
its own definition line — if nothing else matches, it is dead code and the handler trusts raw input:

```bash
grep -rnE 'verifyCallbackData|verify_callback|checkCallback|verifyHash|verify_hash|verify_ipn|check_ipn' \
     --include=*.php . | grep -vE 'function (verifyCallbackData|verify_callback|verifyHash)'
```

If the only hit is the `function ...` definition → **bypass confirmed at source level**. Names to look
for: `verifyCallbackData`, `verifyCallback`, `checkIpnRequestIsValid`, `validate_ipn`, `verify_hash`,
`checkSignature`. Also grep the raw entry point for any of: `hash_equals`, `hash_hmac`, `md5(`,
`$this->meta['api_key']`, `secretKey` — if the entry method body contains none, it verifies nothing.

## Step 2 — Prove the contract with the framework's OFFICIAL reference gateway

"This looks wrong" is weak; "the framework's own reference implementation verifies here, this one
doesn't" is airtight. List the framework org's repos and read an equivalent official gateway:

```bash
curl -s "https://api.github.com/orgs/blesta/repos?per_page=100" | python3 -c 'import sys,json;[print(r["name"]) for r in json.load(sys.stdin)]'
curl -sL "https://raw.githubusercontent.com/blesta/gateway-coinpayments/master/coin_payments.php"
curl -sL "https://raw.githubusercontent.com/blesta/gateway-perfectmoney/master/perfect_money.php"
```

Cite the exact contrast — e.g. CoinPayments `validate()` calls `checkIpnRequestIsValid($post)`
("Ensure IPN is verified…"); PerfectMoney recomputes `md5(...)` and only sets `approved` when
`$post['V2_HASH'] == $v2_hash`. The vulnerable plugin does neither.

## Step 3 — Sweep the whole product family

Vendors ship one bug across every integration. Enumerate siblings and grep each for the same pattern:
WooCommerce, EDD, OpenCart, PrestaShop, Blesta, WHMCS, Magento, plus Node/Python/Java SDKs (SDKs that
use `===`/`==` on a hex HMAC digest are generally safe — the bug is in the *handler*, not the SDK).
Report which products share the flaw and which are clean.

## Step 4 — Build the PoC: verbatim-load harness + fixed control

A source read alone is not accepted (this user requires a runnable PoC). Do **not** re-implement the
plugin — load it **unmodified** and drive its real entry point.

1. `require` the real plugin file.
2. Stub the minimal framework surface (base class, `DS`, `Loader`, `Language`, view object).
3. Instantiate, inject the merchant key via the plugin's **real setter** (`setMeta(['api_key'=>…])`).
4. Call the entry point with a forged payload (bogus hash, then no hash) and print the returned status.
5. Make a `_fixed.php` copy with the one-line fix (entry point calls the verifier first) and run the
   **same** payloads → assert forged **rejected**, legit signed **accepted**. This proves the missing
   check is the sole root cause (not a harness artifact).
6. Optional `e2e.php`: replicate the framework-core step that applies the returned transaction, to show
   the end state (`invoice #556 $999.00 MARKED PAID`).

Copy-paste starter: `templates/php_plugin_harness.php`. Concrete worked case + exact commands +
evidence: `references/blesta-plisio-case.md`.

## Step 5 — Upgrade to the REAL framework core (do this when the PoC is challenged)

**Evidence ladder — know which rung you're on.** This user (and any serious triager) treats these as
*not equivalent*:

| Tier | What it is | Verdict |
|---|---|---|
| 1 | source read, prose argument | weak — never submit alone |
| 2 | stub harness (your own re-implementation of the framework dispatch) | "proves plugin logic, **not core semantics**" — challenged |
| 3 | **real framework core distro + verbatim dispatch excerpt** | accepted — the target here |

A stub harness draws the question *"is your stub faithful to the real framework?"* Kill that doubt by
running the framework's **own shipped code**. This is the upgrade that turns a challenged PoC into an
accepted one:

1. **Get the real distro.** For Blesta, the official download page lists every core version; grep the
   version links, sort, take the newest, `curl` the zip, `sha256sum` it. (Self-hosted products publish
   a versioned tarball — prefer it over a GitHub mirror so the hash is citable.)
2. **Extract the real dispatch method byte-for-byte.** Slice the exact line range of the method that
   calls your entry point (`processNotification()` → `validate()` → `Transactions::apply()`) and embed
   it in the harness **verbatim**.
3. **Load the real core classes unmodified** (`gateway.php`, `nonmerchant_gateway.php`, trait files)
   and the **real plugin unmodified**. Stub only the framework *services* the excerpt touches (DB
   models, mail, container) so it runs head-less — never the logic under test.
4. **Prove byte-identity.** `diff` the embedded excerpt against the upstream lines; assert 0
   differences in the harness's own output. This is the single most convincing artifact.
5. **Show the vendor's own verifier rejecting the same payload** in the same run — e.g.
   `verifyCallbackData(forged) = false` printed right next to `>>> BYPASS CONFIRMED`. It proves the bug
   is real in the code, not an artifact of your harness.

**Ship a re-runnable `verify.sh`** (`scripts/verify_verbatim_harness.sh`): it re-hashes every input
file, re-proves the excerpt is byte-identical, and re-runs the exploit, exiting non-zero on any
mismatch. Reviewers run one command instead of trusting your transcript.

**Wire-request line.** Print the literal HTTP request the attacker sends
(`POST /callback/gw/1/plisio/?client_id=1&invoices=42=149.99` + body) so the reader sees the exploit is
one unauthenticated request, not an internal-function call. Derive it from the plugin's own
callback-URL builder (e.g. `buildProcess()` concatenates `?client_id=…&invoices=…` onto
`gw_callback_url`) so the parameter placement is provably correct.

## Pitfalls (learned the hard way)

- **Excerpt line range must close every brace.** Slicing the dispatch method to an arbitrary line
  (e.g. 528–648) left `Unclosed '{'` → fatal parse error. Read the source, find the line that closes
  the method (here 698), and slice through it; then `php -l` before running.
- **Stub the container / model loader, not the logic.** Real core calls
  `Configure::get('container')->get('requestor')`, `$this->Logs->add()`,
  `$this->Transactions->…`, and private helpers like `logApplyErrors()`. Provide a `Loader` stub that
  injects no-op services on `loadModels/loadComponents/loadHelpers`, a container stub returning a
  `requestor` object, and a private no-op `logApplyErrors()` — otherwise you get
  *"Call to undefined method"* mid-run. Stub only what the excerpt references.
- **PHP property visibility fatal.** If the plugin declares `private $meta` and your stub base class
  also declares `protected $meta`, PHP dies: *"Access level to Plisio::$meta must be protected (as in
  class NonmerchantGateway) or weaker"*. **Do not declare `$meta` in the stub base at all** — let the
  plugin own it, and set it via its real setter.
- **Use the real setter, not reflection.** Call `setMeta([...])` / `loadConfig()` exactly as the
  framework does; poking private props directly breaks the visibility model.
- **`!=` vs `hash_equals`.** Loose `!=` on an HMAC **hex** digest is *mostly* safe from magic-hash
  juggling (hex output rarely parses as the `0e…` numeric form), so don't overclaim a type-juggling
  bypass — but flag it as hardening (`hash_equals`).
- **Missing `break` fall-through.** `switch ($post['status']) { case 'new': … case 'completed': … }`
  with no `break` after `new` records *unpaid* `new` callbacks as `completed`. Separate low/medium bug.
- **Docs behind WAF.** `curl` to framework docs may return 403; use the browser, or just read the
  official gateway source on GitHub (usually enough to establish the contract).
- **Don't inflate severity.** Signature bypass is integrity-only; keep CVSS honest and let the business
  impact carry the weight.

## Fix to recommend

```php
public function validate(array $get, array $post)
{
    if (!$this->verifyCallbackData($post, $this->meta['api_key'])) {
        return null; // reject unsigned / forged callbacks
    }
    // ... existing logic
}
```
Plus: never trust `source_amount`/`source_currency` from the callback — reconcile against the invoice total.

## Disclosure

If the project is **not** on immunefi/HackerOne (typical for CMS/billing plugin repos), do **direct
responsible disclosure** to the vendor: source audit + isolated local PoC, no live exploitation of any
production callback URL. Confirm reward/bounty terms before sending the full writeup. See
`report-writing` and `triage-validation` before submitting.
