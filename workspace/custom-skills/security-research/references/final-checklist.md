# Reference: Category-Specific Pre-Submission Checklist

> Run alongside SKILL.md FINAL REVIEW — this is domain-specific,
> that one is universal. Both required before SUBMISSION_READY.

### Bridge
- [ ] Message verifier + threshold identified and documented?
- [ ] Replay/retry protected by unique nonce/message ID?
- [ ] Initial state post-deploy/upgrade verified safe?
- [ ] Off-chain control (RPC, relayer) noted if out-of-scope?

### Lending / Perps
- [ ] All price sources validated (staleness, deviation, correct account)?
- [ ] Caps/LTV/fee consistent across all entry paths?
- [ ] Admin instructions validate their own input?

### Vault / Pool
- [ ] First-depositor/share-inflation protection checked?
- [ ] State-update vs external-call ordering verified?
- [ ] Rounding favors protocol, not attacker?

### Signature / Auth
- [ ] Every security-relevant field included in signed payload?
- [ ] Nonce, deadline, chainId, verifying contract all present?

### Upgradeability
- [ ] `initialize` can't be re-called or called by unauthorized party?
- [ ] Storage layout compatible across versions?

---

# ADDENDUM — Web2 / Mobile sections (team addendum 2026-10-03, appended at the operator's direction — the sections above are unchanged)

### Web2 / API
- [ ] Two-account authorization replay done (horizontal + vertical) on every object endpoint in scope?
- [ ] Session invalidated on logout AND on password/credential change?
- [ ] CSRF: sensitive state changes require a token the attacker cannot obtain (and SameSite posture checked)?
- [ ] File upload: type AND content validated, stored outside webroot / served non-executable?
- [ ] SSRF: destination allowlist or internal-range blocking verified with OOB evidence, redirects re-validated?
- [ ] OAuth: redirect_uri strictly validated, state present, PKCE where supported, code single-use?
- [ ] GraphQL (if present): per-field/per-resolver authorization tested, not just endpoint-level?

### Mobile (Android / iOS)
- [ ] Credentials stored ONLY in platform keystore (Android Keystore / iOS Keychain) — no tokens or renewal secrets in SharedPreferences / NSUserDefaults / plain files / local DBs?
- [ ] No tokens in URLs, logs, or telemetry attributes (check what the client actually sends, not just what the code intends)?
- [ ] Exported components permission-gated; deep links / URL schemes validate caller and parameters before privileged actions?
- [ ] WebView: JS bridge exposure scoped to trusted origins, file access off unless required, remote content never reaches privileged bridges unvalidated?
- [ ] TLS: platform default validation intact (no permissive challenge handler / trust manager); pinning present or its absence a documented design decision?
- [ ] Backup / app-data extraction posture checked (backup flags, app-group containers, pasteboard) for anything credential-grade?
- [ ] Shipped artifact diffed against audited source (store binary == repo) before claims are made about either?
