---
skill: ios
title: "iOS Testing"
category: "Security · Mobile"
load_when: "Any iOS app in scope."
pack: SUPERAGENT V10
bughunt: true
---
# iOS Testing

## Where it pays
Secrets, insecure storage, backend discovery; URL-scheme/pasteboard IPC.

## Signals
Info.plist URL schemes/ATS/entitlements; keychain flags; WKWebView.

## Methodology
1. frida-ios-dump; inspect binary/plist.
2. objection: keychain dump, pinning + JB-detect + biometric bypass.
3. Storage: NSUserDefaults/CoreData/keychain/pasteboard.
4. URL scheme hijack; insecure WKWebView.
5. Proxy → test API.

## Validation gate
Live secret, token at rest, IPC leak, or backend bug via discovered API.

## Impact & chains
secrets → backend/cloud; URL-scheme flaws → client compromise; API → **ATO**.

**→ next: `../api/*`.**
