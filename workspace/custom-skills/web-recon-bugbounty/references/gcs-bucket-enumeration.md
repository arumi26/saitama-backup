# GCS Bucket Enumeration & Cloud Storage Discovery

## Detection
When a subdomain returns these headers, it's likely a Google Cloud Storage bucket:
```
x-guploader-uploadid: ...
server: UploadServer
x-goog-metageneration: ...
x-goog-hash: crc32c=...
```

## Public Listing Check
```bash
curl -s https://assets.TARGET/ | head -100
```

If it returns XML with `<ListBucketResult>`, the bucket is publicly listable. This exposes:
- Full directory structure
- All file names and sizes
- Last modified dates
- ETags (MD5 hashes)

## Common Subdomain Patterns
- `assets.TARGET` — static assets, branding, logos
- `cdn.TARGET` — CDN origin bucket
- `storage.TARGET` — general storage
- `files.TARGET` — document storage
- `media.TARGET` — media files
- `uploads.TARGET` — user uploads

## What to Look For
1. **Sensitive documents**: audit reports, white papers, internal docs
2. **API keys/secrets**: config files, .env files, credentials
3. **Asset inventory**: full list of supported tokens, stocks, products
4. **Branding assets**: logos, icons (supply chain attack surface)
5. **Backup files**: database dumps, exports

## Exploitation
1. **Download sensitive files**: `curl -s https://assets.TARGET/docs/audit-report.pdf -o audit.pdf`
2. **Enumerate all files**: Parse XML response for complete file listing
3. **Check for write access**: `curl -X PUT -d "test" https://assets.TARGET/test.txt` (rare but high impact)

## Remediation
- Disable public listing on GCS buckets
- Use signed URLs for sensitive files
- Implement proper IAM policies
- Regular audit of bucket permissions

## Case Study: Edel Finance (2026-07)
- `assets.edel.finance` had public listing enabled
- Exposed: audit report (7.1MB), white paper (530KB), all stock/token branding
- Full directory structure of tokenized assets visible
- Company used GCS for static asset hosting without access controls
