---
skill: crlf-injection
title: "CRLF Injection / HTTP Response Splitting"
category: "Security · Web"
load_when: "crlf injection, http response splitting, header injection, response splitting, %0d%0a, log injection, set-cookie injection"
pack: SUPERAGENT V10
bughunt: true
---

# CRLF Injection / HTTP Response Splitting

## Where it pays
Injecting `\r\n` into headers lets you forge headers, split responses, poison caches, set cookies, and sometimes land XSS — a versatile mid-tier class.

## Attack-surface signals
User input reflected into response headers: redirects (`Location`), `Set-Cookie`, custom headers, log entries, URL params echoed into headers, proxies that forward raw values.

## Methodology
1. **Find header reflection:** a param value appearing in any response header (often `Location` on redirect).
2. **Inject CRLF:** `%0d%0a` (and variants `%0D%0A`, `%E5%98%8A%E5%98%8D` overlong, `\u560a`).
3. **Forge a header:** `...%0d%0aSet-Cookie:sessationfixation=1`.
4. **Response splitting → XSS:** inject a full second response with a body (`%0d%0a%0d%0a<script>...`).
5. **Cache poisoning:** split response cached and served to others.
6. **Log injection:** forge log lines; sometimes chains to log4shell-style sinks.

## Payloads / probes
```
%0d%0aSet-Cookie:x=1
%0d%0aLocation:https://evil.com
%0d%0a%0d%0a<script>alert(document.domain)</script>
%E5%98%8A%E5%98%8DSet-Cookie:x=1    (overlong/unicode bypass)
/%0d%0aContent-Length:0%0d%0a%0d%0aHTTP/1.1 200 OK...
```

## Root causes
Raw user input placed into a response header without stripping `\r`/`\n` · redirect targets not sanitized · header-setting APIs that don't filter newlines.

## Validation gate
Show an injected header taking effect (a forged Set-Cookie/redirect in the response), a split second response, or resulting XSS/cache poisoning.

## Impact & chains
Header forgery, session fixation, XSS, cache poisoning, open redirect. Chains with web/xss, web/cache-poison, web/open-redirect.

## 🧪 Try it locally
```bash
python3 ../../../tools/payload_gen.py crlf
python3 ../../../tools/skill_router.py "crlf injection response splitting header"
```

→ Report with `../reporting/writeup.md` (CWE-93); validate with `../reporting/validation-gate.md`.
