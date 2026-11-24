---
skill: grpc
title: "gRPC / Protobuf Security"
category: "Security · API"
load_when: "grpc, protobuf, grpc-web, protocol buffers, grpc reflection, grpc fuzzing, api modern"
pack: SUPERAGENT V10
bughunt: true
---

# gRPC / Protobuf Security

## Where it pays
gRPC APIs are under-tested — reflection leaks the schema, and authz/validation gaps are common.

## Attack-surface signals
gRPC endpoints (:50051 etc), grpc-web over HTTP/2, .proto files, binary protobuf payloads, reflection service enabled.

## Methodology
1. **Reflection:** if enabled, dump the full service schema (grpcurl -plaintext target list).
2. Enumerate methods; call them with grpcurl — test authz on each (BOLA/BFLA over gRPC).
3. Mass assignment via extra protobuf fields; integer/enum confusion.
4. Metadata/auth: bypass via missing/forged metadata (the gRPC equivalent of headers).
5. grpc-web: downgrade, CORS, same web attacks through the JSON/base64 bridge.
6. Fuzz protobuf fields ( grpc-fuzz); DoS via large/nested messages.

## Payloads / probes
```
grpcurl -plaintext target:50051 list
grpcurl -plaintext -d '{"id":"VICTIM"}' target:50051 svc.Method
grpcurl -H 'authorization: ' ...   # test missing auth
```

## Root causes
Reflection on in prod · per-method authz missing · protobuf fields bound without allowlist · metadata auth not enforced.

## Validation gate
Show cross-user/privileged data or an action via a gRPC method you shouldn't reach.

## Impact & chains
BOLA/BFLA over gRPC · mass assignment · schema disclosure. Chains with api/rest-authz and api/mass-assignment.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "grpc, protobuf, grpc-web, protocol buffers, grpc reflection, grpc fuzzing, api modern"
```

→ Report with `../reporting/writeup.md`; validate with `../reporting/validation-gate.md`.
