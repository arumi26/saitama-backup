---
skill: prototype-pollution
title: "Prototype Pollution (JS/Node)"
category: "Security · Web"
load_when: "prototype pollution, __proto__, constructor prototype, js pollution, node pollution, gadget, client-side prototype pollution"
pack: SUPERAGENT V10
bughunt: true
---

# Prototype Pollution

## Where it pays
A hot, often-critical JS/Node class. Polluting `Object.prototype` can flip security flags, inject properties, cause DoS, or chain to XSS/RCE via gadgets.

## Attack-surface signals
JSON merge/extend/clone utilities (lodash merge, jQuery extend), query-string parsers, config loaders, any `obj[key] = value` with user-controlled `key`, server-side template engines, client-side sinks reading from location.

## Methodology
1. **Server-side (Node):** send `__proto__`, `constructor.prototype`, or `prototype` keys in JSON/query — `{"__proto__":{"polluted":true}}`.
2. **Confirm:** check a reflected/behavioral change (an unexpected property appears globally, a default flips).
3. **Gadget hunt:** find code that reads an object property that was never set — that's your sink. Pollute it (`isAdmin`, `shell`, template options).
4. **Client-side (CSPP):** pollute via URL/`location` into DOM sinks → XSS (e.g. gadget in a sanitizer/template).
5. **DoS:** pollute properties that break later logic.
6. **RCE chain (Node):** pollute options consumed by `child_process`, template engines (`pug`, `ejs`), or spawn env.

## Payloads / probes
```
{"__proto__":{"polluted":"yes"}}
{"constructor":{"prototype":{"polluted":"yes"}}}
?__proto__[polluted]=yes
?constructor[prototype][polluted]=yes
{"__proto__":{"isAdmin":true}}
{"__proto__":{"shell":"node","argv0":"..."}}   # gadget-dependent RCE
```

## Root causes
Recursive merge/clone that copies `__proto__`/`constructor` · `obj[userKey]=val` without key allowlist · old lodash/jQuery/minimist · trusting object keys from input.

## Validation gate
Show a global property change affecting other requests/users, a polluted security flag taking effect, or a concrete gadget chain (XSS/DoS/RCE) — not just that `__proto__` was accepted.

## Impact & chains
Privilege flags flipped · DoS · XSS (client-side) · RCE (gadget). Chains with web/xss (CSPP→XSS) and exploit-dev (Node RCE gadgets).

## 🧪 Try it locally
```bash
python3 ../../../tools/payload_gen.py prototype
python3 ../../../tools/skill_router.py "prototype pollution __proto__ node"
```

→ Report with `../reporting/writeup.md` (CWE-1321); validate with `../reporting/validation-gate.md`.
