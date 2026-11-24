---
skill: android
title: "Android Testing"
category: "Security · Mobile"
load_when: "Any Android APK in scope; the app maps the backend."
pack: SUPERAGENT V10
bughunt: true
---
# Android Testing

## Where it pays
Hardcoded secrets, insecure storage, IPC flaws, and discovered backend APIs.

## Signals
Manifest exported components/debuggable/allowBackup/deep links; network_security_config; hardcoded keys.

## Methodology
1. Pull APK; jadx/apktool; grep secrets/urls.
2. Frida/objection: bypass root/pinning, dump keystore.
3. Proxy + system CA → test API (api/*).
4. Storage: shared_prefs/sqlite; logcat; WebView bridges.
5. Exported components, content providers, deep links.

## Validation gate
Live secret, token at rest, IPC leak, or backend bug via discovered API.

## Impact & chains
secrets → cloud/backend; discovered API → BOLA/mass-assign → **ATO**.

**→ next: `../api/*`, `../phases/04-chain.md`.**
