# Server-side fetch of a user-supplied URL — SSRF guard review

Use when a server route takes a URL from attacker data. Typical: OpenGraph/link-preview
card routes (`/api/og/[kind]/[id]`), avatar proxies, "import from URL", PDF/image
renderers, webhook testers, RSS/feed fetchers, screenshot services.

Severity is high here because the request originates from the **server's** network position.

## The four bypasses that defeat naive guards

| # | Bypass | Why a naive guard misses it | Fix |
|---|--------|------------------------------|-----|
| 1 | Redirect to internal | Guard checks the URL, then `fetch` follows a 302 to `169.254.169.254` | `redirect: 'manual'`, treat 3xx as failure |
| 2 | Literal IP in URL | Guard only does DNS lookup; `http://169.254.169.254/` never resolves | `isIP(host)` → check directly, skip DNS |
| 3 | DNS rebinding / partial resolve | Guard checks only the first A record | `lookup(host, { all: true })` and require **every** address public |
| 4 | IPv6 encodings | IPv4 logic doesn't apply to `::ffff:169.254.169.254` | Explicit IPv6 branch (table below) |

Also: the guard must run **before** the fetch, and the `content-type`/size checks must run
**after** — an image MIME check is not an SSRF defence, it is a decode-safety check.

## Private / non-public ranges to refuse

IPv4:

```
0.0.0.0/8          a === 0
10.0.0.0/8         a === 10
127.0.0.0/8        a === 127                (loopback)
169.254.0.0/16     a === 169 && b === 254   (link-local + AWS/GCP/Azure metadata)
172.16.0.0/12      a === 172 && 16 <= b <= 31
192.168.0.0/16     a === 192 && b === 168
192.0.0.0/24       a === 192 && b === 0 && c === 0   (IETF protocol assignments)
198.18.0.0/15      a === 198 && (b === 18 || b === 19) (benchmarking)
100.64.0.0/10      a === 100 && 64 <= b <= 127       (CGNAT)
224.0.0.0/4+       a >= 224                          (multicast / reserved / 255.255.255.255)
```

IPv6 — the ones people forget:

```
::1, ::                      loopback / unspecified
::ffff:x.x.x.x               IPv4-mapped  ← MUST refuse; bypasses all IPv4 checks
64:ff9b::/96                 NAT64 well-known prefix
fe80::/10, fec0::/10         link-local, site-local
fc00::/7                     unique-local (fc.., fd..)
```

Unparseable host → **refuse** (fail closed), not allow.

## Known-good guard (Next.js / TypeScript)

This is the shape that was verified correct in the case study. Copy it rather than
re-deriving the range table.

```ts
import { lookup } from 'node:dns/promises';
import { isIP } from 'node:net';

/** True for loopback, private, link-local, unique-local and other non-public ranges. */
function isPrivateAddress(ip: string): boolean {
  const v = isIP(ip);
  if (v === 4) {
    const p = ip.split('.').map(Number);
    if (p.length !== 4 || p.some(Number.isNaN)) return true;
    const [a, b, c] = p;
    return (
      a === 0 || a === 10 || a === 127 ||
      (a === 169 && b === 254) ||               // link-local + cloud metadata
      (a === 172 && b >= 16 && b <= 31) ||
      (a === 192 && b === 168) ||
      (a === 192 && b === 0 && c === 0) ||
      (a === 198 && (b === 18 || b === 19)) ||
      (a === 100 && b >= 64 && b <= 127) ||     // CGNAT
      a >= 224                                   // multicast / reserved
    );
  }
  if (v === 6) {
    const s = ip.toLowerCase();
    return (
      s === '::1' || s === '::' ||
      s.startsWith('::ffff:') ||                 // IPv4-mapped
      s.startsWith('64:ff9b') ||                 // NAT64
      /^fe[89a-f]/.test(s) ||                    // link-local + site-local
      s.startsWith('fc') || s.startsWith('fd')   // unique-local
    );
  }
  return true; // unparseable → refuse
}

/** Resolve the URL's host and confirm every address it maps to is public. */
async function isPublicHttpsHost(url: string): Promise<boolean> {
  let host: string;
  try {
    const u = new URL(url);
    if (u.protocol !== 'https:') return false;   // https-only kills gopher/file/etc.
    host = u.hostname;
  } catch {
    return false;
  }
  if (isIP(host)) return !isPrivateAddress(host); // literal IP — no DNS to bypass
  try {
    const addrs = await lookup(host, { all: true });
    return addrs.length > 0 && addrs.every(a => !isPrivateAddress(a.address));
  } catch {
    return false;
  }
}
```

Call site:

```ts
if (!(await isPublicHttpsHost(url))) return null;

const controller = new AbortController();
const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
try {
  const res = await fetch(url, {
    signal: controller.signal,
    headers: { accept: 'image/*' },
    redirect: 'manual',                 // ← the redirect bypass fix
  });
  if (res.status >= 300 && res.status < 400) return null;  // no follow
  if (!res.ok) return null;

  const mime = (res.headers.get('content-type') || '').split(';')[0].trim();
  if (!ALLOWED_MIME.test(mime)) return null;

  const declared = parseInt(res.headers.get('content-length') || '0', 10);
  if (declared > MAX_BYTES) return null;       // header is a hint only

  const buf = Buffer.from(await res.arrayBuffer());
  if (buf.length === 0 || buf.length > MAX_BYTES) return null;  // real bound

  return `data:${mime};base64,${buf.toString('base64')}`;
} catch {
  return null;                                  // fail closed, no stack to client
} finally {
  clearTimeout(timer);
}
```

## What to actually flag

Only flag a **missing control**, and name it:

- `redirect: 'follow'` (the default) on a user-supplied URL → **reportable**, redirect bypass.
- DNS-only check with no `isIP` branch → **reportable** for literal-IP targets.
- No IPv6 branch → **reportable** (`::ffff:169.254.169.254`).
- No timeout → **reportable** as DoS on the lambda/worker, low severity.
- `content-type` not checked → decode-safety, not SSRF; usually informational.

## What NOT to flag

- `connect-src https:` being broad in the app's **CSP** — that governs the browser, not the
  server fetch. Different threat model, don't conflate them.
- The route returning a static fallback image on failure — that is correct behaviour.
- Stack traces in a `?debug=1` branch **gated on `NODE_ENV !== 'production'`** — deliberate
  and safe. Only flag it if the gate is missing.

## Verification without an install

`node:dns`/`node:net` reasoning needs no `node_modules`. You can exercise `isPrivateAddress`
logic by transcribing it into a scratch file and running it against a table of cases
(`169.254.169.254`, `::ffff:169.254.169.254`, `10.0.0.1`, `100.64.0.1`, `198.18.0.1`,
`8.8.8.8`, `2001:4860:4860::8888`). Cheap, and it proves the guard rather than trusting it.
