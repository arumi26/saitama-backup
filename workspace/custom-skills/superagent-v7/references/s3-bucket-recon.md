# S3 Bucket Recon / Public Bucket Hunting

## Teknik Discovery

### 1. AWS S3 Bucket via DNS / CNAME
Seringkali subdomain API atau CDN pointing ke S3 bucket. Cek dengan:
```bash
curl -sI "https://api.target.com" | grep -i server
# Jika "AmazonS3" → bucket S3!
```

### 2. Cek Public Bucket Listing
```bash
curl -s "https://api.target.com/"
# XML response = S3 bucket listable
# JSON 404 = listing disabled
# XML with ListBucketResult = VULNERABLE
```

### 3. Filter Prefix / Delimiter
```bash
curl -s "https://api.target.com/?delimiter=/"
curl -s "https://api.target.com/?prefix=secret/&delimiter=/"
```

### 4. What to Look For
Cari file/directories dengan kata kunci:
- `secret`, `key`, `password`, `credential`, `token`
- `config`, `admin`, `internal`, `backup`
- `env`, `.env`, `.git`
- `database`, `db-`, `auth`
- user wallet addresses / API keys

### 5. Listing via Python
```python
import xml.etree.ElementTree as ET, requests

r = requests.get("https://api.target.com/")
root = ET.fromstring(r.text)
ns = {'s3': 'http://s3.amazonaws.com/doc/2006-03-01/'}
for c in root.findall('.//s3:Contents', ns):
    print(c.find('s3:Key', ns).text)
```

## Case Study: IPOR Protocol (2026-08-02)
- `api.ipor.io` adalah S3 bucket dengan public listing ENABLED
- 1000+ objek: market configs, vault histories, user wallet addresses
- Folder `monitor/apy-leaderboard/accounts/` — ribuan alamat user
- CORS wildcard (`Access-Control-Allow-Origin: *`)
- Ada di Immunefi bounty → bisa di-submit

## Report Template
```
**Target:** [URL]
**Finding:** S3 bucket allows unauthenticated listing
**Severity:** LOW-MEDIUM (info disclosure)

**Steps:**
curl -s "https://[target]/"

**Data exposed:** [list]
**Objects:** [N]

**Remediation:**
Block public listing via S3 bucket policy:
{
  "Statement": [{
    "Effect": "Deny",
    "Principal": "*",
    "Action": "s3:ListBucket",
    "Resource": "arn:aws:s3:::[bucket-name]"
  }]
}
```