---
skill: serverless
title: "Serverless Security (Lambda/Functions)"
category: "Security · Cloud/Infra"
load_when: "serverless, lambda, cloud functions, azure functions, event injection, function url, denial of wallet, cold start"
pack: SUPERAGENT V10
bughunt: true
---

# Serverless Security (Lambda/Functions)

## Where it pays
Serverless shifts the attack surface to events, IAM, and function URLs — often over-permissioned and event-injectable.

## Attack-surface signals
AWS Lambda, GCP/Azure Functions, function URLs, API Gateway→Lambda, event sources (S3/SQS/SNS), environment variables.

## Methodology
1. **Event injection:** poison the event source (filename in S3 trigger, SQS body, SNS) → attacker data reaches the handler unsanitized.
2. **Over-permissioned IAM role:** the function's role can do more than needed → priv-esc / lateral movement (pairs with cloud-misconfig).
3. **Env var secrets:** functions often store keys in env — leak via SSRF/error/info-disclosure.
4. **Function URL / API GW:** auth misconfig, IAM-none, open invoke.
5. **Denial-of-Wallet:** unbounded invocation → cost attack (report carefully).
6. **Injection in handler:** SSRF/cmdi/NoSQLi passed from the event.

## Payloads / probes
```
# S3 event injection: upload with a crafted key/metadata
aws s3 cp evil s3://bucket/$(payload)
# enumerate the function role
aws sts get-caller-identity   # from within (SSRF/leak)
# open function URL
curl https://<id>.lambda-url.region.on.aws/
```

## Root causes
Trusting event data as safe · over-broad execution role · secrets in env vars · function URL without auth.

## Validation gate
Show injected event reaching the handler, role over-permission exploited, or an unauthenticated invoke.

## Impact & chains
Priv-esc via IAM · data/secret theft · code exec in handler · cost attack. Chains with cloud-misconfig and web/ssrf.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "serverless, lambda, cloud functions, azure functions, event injection, function url, denial of wallet, cold start"
```

→ Report with `../reporting/writeup.md`; validate with `../reporting/validation-gate.md`.
