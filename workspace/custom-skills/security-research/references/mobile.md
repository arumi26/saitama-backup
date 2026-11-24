# Reference: MOBILE HUNT (Android / iOS — apps & embedded SDKs)

> Written by the team (2026-10-03) — this file did not exist in the
> original set; it codifies the mobile methodology proven on the Glia hunt.
> Complements `web2.md` (the server side mobile talks to) — this file covers
> the client: what it stores, what it exposes, what it trusts.

Activate when the target:

* ships an official Android/iOS app in program scope;
* ships a mobile SDK/library embedded in customer apps (scope caveat:
  confirm the program's wording covers the library, not only first-party
  apps — record the caveat in the candidate, never silently assume);
* handles sessions, payments, PII, or real-time communication on device.

---

# ENTRY HEURISTIC

Map in this order (highest bounty density first):

1. **Credential storage** — where do session tokens, refresh/renewal
   secrets, and API keys live on device?
2. **Session lifecycle** — issue → store → renew → revoke. The renewal
   path is the crown jewel: whatever renews the session IS the session.
3. **IPC / deep-link surface** — what can OTHER apps and web pages make
   this app do?
4. **WebView bridges** — what native powers are exposed to web content?
5. **Transport** — TLS posture, token placement (headers vs URLs/logs).
6. **Server API as seen by the client** — endpoints/fields the client
   knows that web docs don't show (feed into `web2.md` testing).

---

# ANALYSIS ORDER

1. Artifact acquisition — store binary (APK/AAB/IPA or published SDK
   artifact from the official registry: Maven Central, CocoaPods/SPM,
   npm). Record exact version + hash. The SHIPPED artifact is the
   target; source repos are a map, not the territory.
2. Static pass — manifest/Info.plist (exported components, permissions,
   URL schemes, backup flags, network security config), decompile
   (jadx/apktool) or binary analysis (strings, symbol/metadata xref,
   disassembly of the decisive functions).
3. Storage census — enumerate EVERY persistence mechanism present:
   SharedPreferences / NSUserDefaults, SQLite/CoreData/Room, plain
   files, Keychain/Keystore, caches (HTTP disk cache!), WebView
   storage, app-group shared containers, pasteboard.
4. Session & renewal trace — follow the token from login response to
   storage to every use; find the renewal call and what authenticates
   it (a stored secret sent as its own credential = the finding shape).
5. IPC / deep-link trace — every exported component and scheme handler:
   what action, what parameters, what caller validation.
6. WebView trace — bridge methods, origin/frame discipline, file
   access settings, which content (remote? user-influenced?) can reach
   the bridge.
7. Transport trace — TLS validation path (custom challenge handlers /
   trust managers = red flag), pinning presence, token in URL query
   (WebSocket handshakes!), token in logs/telemetry attributes.
8. Shipped-vs-source diff — if a public repo exists, verify the shipped
   artifact matches it on the audited behaviors; audit the binary where
   they diverge. Never claim binary behavior from source alone, or
   source behavior from the binary alone.
9. Platform parity — whatever you find on one platform, check the
   other. Divergence is evidence: the platform that does it safely
   proves the unsafe one is a defect, not a design requirement.
10. Runtime proof where the lab allows it — execute the shipped code
    (unit harness / Robolectric-style / instrumentation) with
    FABRICATED values only; on-disk or on-wire output is the receipt.
    Static-only conclusions are labeled as such, never dressed as
    runtime.

Rule: do not skip the census (step 3) because the first store looked
clean — findings live in the SECOND store (the forgotten cache, the
legacy database kept for migration, the shared container).

---

# STORAGE — THE QUESTIONS

* Are credentials encrypted at rest with platform keystore keys
  (EncryptedSharedPreferences / Android Keystore / iOS Keychain)?
* What EXACTLY is stored: token only, or token + renewal secret +
  identifiers? Identifiers alone are low value; renewable credentials
  are account takeover with a local-read precondition.
* HTTP caches: is a disk cache enabled on the authenticated client?
  Cached responses can persist transcripts/PII AND the Authorization
  header itself — persistence depends on server Cache-Control; claim
  the code-level enablement, mark the per-response part UNKNOWN.
* Backups: does the data ride along in cloud/device backups
  (allowBackup, backup exclusion keys)? Backup extraction is a
  standard forensic path.
* Cleanup: does logout/session-clear actually wipe every store found
  in the census? Partial wipe = leftover credential.

---

# TRANSPORT & SESSION

* Token placement: Authorization header (good) vs URL query (leaks to
  logs, proxies, telemetry, referrers — check WebSocket handshake URL
  construction in EVERY socket stack the app ships, including KMM/
  cross-platform layers) vs POST body.
* Telemetry/logging: do log pipelines receive URLs or headers verbatim?
  Trace the attribute from log call to exporter; redaction that exists
  in one logging path often does not cover the telemetry path.
  Redaction regexes: TEST them against the token formats in play
  (opaque tokens and header-order edge cases slip naive patterns).
* TLS: platform default validation intact? Search for permissive
  challenge handlers, empty X509TrustManager, hostname-verifier
  overrides. Absence of pinning alone is a design observation, not a
  finding, unless the program says otherwise.
* Renewal semantics: can the stored secret renew forever? Is renewal
  bound to device/key, rate-limited, revocable on password change?
  Client-side expiry handling present, or does the client trust the
  server blindly (fine) while storing the secret forever (not fine)?

---

# IPC / DEEP LINKS / WEBVIEW

* Exported activities/services/providers/receivers: permission checks,
  caller validation, what a malicious co-resident app can invoke or
  read (content providers are the classic silent data leak).
* Deep links / app links: parameters trusted (IDs, URLs, tokens)?
  Verified app links vs custom schemes (schemes are claimable by any
  app — never a trust boundary).
* Push notifications: payload contents (PII in notification body =
  lock-screen disclosure), action handling validating the session/
  object it acts on?
* WebView: JS bridges reachable from which origins/frames; `file://`
  access; universal-access-from-file-URLs; remote debugging flags;
  content loaded from server-supplied URLs into a bridged WebView.

---

# EVIDENCE GATE (same ladder as everywhere in this set)

* A decompiled code path is REPRODUCED only when the shipped code is
  executed or the data flow is traced end-to-end without gaps; label
  static-only traces honestly (CODE-CONFIRMED is a trace grade, say
  what was not executed).
* REACHABILITY applies to local preconditions too: state plainly WHAT
  local access the attack needs (root/forensic/co-resident app/backup)
  and what it converts to. A plaintext token that cannot be renewed is
  a smaller finding than a renewable secret — grade the conversion,
  not the storage alone.
* UNKNOWN server-side behavior (revocation, Cache-Control, scope
  enforcement) stays UNKNOWN in the report; the client-side evidence
  stands on its own legs.

---

# PROGRAM NOTES

* Many programs scope "official apps" — an embedded SDK's eligibility
  can be genuinely ambiguous. Write the scope argument INTO the report
  honestly (whose code, whose users, who can fix it) and let triage
  decide; never hide the library nature of the component.
* Method rules still bind: no testing against other users' devices or
  accounts; your device/emulator, your accounts, fabricated data for
  harnesses.
