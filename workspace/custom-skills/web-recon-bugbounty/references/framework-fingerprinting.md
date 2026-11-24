# Framework Fingerprinting via Error Messages

## Fastify (Node.js)
Error code pattern: `FST_ERR_CTP_*`
```json
{
  "statusCode": 400,
  "code": "FST_ERR_CTP_INVALID_JSON_BODY",
  "error": "Bad Request",
  "message": "Body is not valid JSON but content-type is set to 'application/json'"
}
```

**Common Fastify error codes:**
- `FST_ERR_CTP_INVALID_JSON_BODY` — Invalid JSON in request body
- `FST_ERR_CTP_EMPTY_JSON_BODY` — Empty JSON body
- `FST_ERR_CTP_INVALID_MEDIA_TYPE` — Unsupported Content-Type
- `FST_ERR_CTP_MISSING_CONTENT_TYPE` — No Content-Type header
- `FST_ERR_CTP_BODY_TOO_LARGE` — Request body exceeds limit

**Detection:**
```bash
curl -s -X POST -H "Content-Type: application/json" -d 'invalid' https://TARGET/api/endpoint
```

## Express.js
```
Cannot GET /path
Cannot POST /path
```

## NestJS
- Uses Fastify or Express under the hood
- Swagger UI at `/docs` (not `/swagger-ui.html`)
- OpenAPI spec at `/docs/json` (not `/openapi.json`)
- Health check at `/health` (not `/actuator/health`)

## Vercel-Specific Findings

### Deployment ID Exposure
Next.js apps on Vercel expose deployment IDs in HTML:
```bash
curl -s https://TARGET/ | grep -o 'dpl_[A-Za-z0-9]*'
# Result: dpl_GSR8A8G6xm5X1mdKZq8zT6ZwxU59
```

**Impact:** Reveals deployment history, can be used to enumerate past deployments.

### Vercel Security Checkpoint
When Vercel's bot protection is active, curl requests to JS chunks return 403 with:
```html
<title>Vercel Security Checkpoint</title>
```

**Workaround:** Use browser tools or set appropriate User-Agent headers.

### Vercel Challenge Token
```
x-vercel-challenge-token: 2.1784209733.60.MWVjMDJmYmRl...
x-vercel-mitigated: challenge
```

### Vary Header Leaks
```
vary: rsc, next-router-state-tree, next-router-prefetch, next-router-segment-prefetch
```
Confirms Next.js app with React Server Components.

## React Server Components (RSC) Payload
Next.js 13+ apps embed RSC payload in HTML:
```html
<script>self.__next_f.push([1,"..."])</script>
```

**Extract route structure:**
```bash
curl -s https://TARGET/ | grep -o 'self.__next_f.push([^)]*)' | head -5
```

**What's exposed:**
- Component tree structure
- Route paths
- Module IDs
- Import paths for chunks

## Case Study: Edel Finance API (2026-07)
- Fastify backend on `api.edel.finance`
- Exposed via `FST_ERR_CTP_INVALID_JSON_BODY` error
- Swagger UI at `/docs` (not `/swagger-ui.html`)
- OpenAPI spec at `/docs/json`
- Health endpoint leaked uptime: `{"status":"ok","uptimeSeconds":1433327}`
- No rate limiting on any endpoint
