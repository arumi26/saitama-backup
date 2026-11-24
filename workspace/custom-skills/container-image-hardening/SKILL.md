
# Container Image Hardening

Review and fix Dockerfiles and images for production safety.

## Dockerfile Review Checklist

- **Base image**: official, specific tag or digest, minimal variant (`alpine`, `distroless`, `slim`); never `latest`
- **Multi-stage builds**: build toolchains (compilers, package managers) excluded from final image
- **Non-root user**: `USER` directive with a dedicated UID; no sudo in image
- **No secrets**: no `ENV` with credentials, no `COPY .env`, no secrets baked into layers (they persist even if deleted later)
- **Pinned dependencies**: lockfiles used (`npm ci`, `pip install -r requirements.txt` with hashes)
- **Healthchecks** defined; `ENTRYPOINT` over `CMD` for enforced init
- **Layer hygiene**: combine apt operations and clean lists in one layer; `.dockerignore` covers `.git`, build artifacts

## Scan and Gate

```bash
trivy image --severity HIGH,CRITICAL --exit-code 1 <image>
grype <image>
docker scout cves <image>
```

- Fail CI on critical CVEs with available fixes
- Track base image updates (renovate/dependabot for Dockerfiles)

## Runtime Hardening

```yaml
read_only: true
cap_drop: ["ALL"]
security_opt: ["no-new-privileges:true"]
tmpfs: [/tmp]
```

- Resource limits set (CPU/memory) to blunt DoS
- Root filesystem read-only; writable paths explicit tmpfs

## Verification

- `docker history <image>` — no secret-looking layers
- `dive <image>` — image efficiency and wasted space
- Run as the image user: `docker run --rm <image> id` shows non-root

## Output

Hardened Dockerfile, scan report before/after, and CI gate configuration.
