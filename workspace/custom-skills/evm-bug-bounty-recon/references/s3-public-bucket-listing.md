# S3 Bucket Public Listing Detection

## How to find

When a website's API returns an XML response at root, it's probably an S3 bucket listing:

```bash
curl -s "https://api.target.com/"
# If returns <?xml version="1.0" encoding="UTF-8"?>
# with <ListBucketResult> — you found an S3 bucket!
```

## S3 XML listing parser

```bash
curl -s "https://api.target.com/" | python3 -c "
import sys, xml.etree.ElementTree as ET
raw = sys.stdin.read()
root = ET.fromstring(raw)
ns = {'s3': 'http://s3.amazonaws.com/doc/2006-03-01/'}
for contents in root.findall('.//s3:Contents', ns):
    key = contents.find('s3:Key', ns)
    if key is not None:
        print(key.text)
"
```

## Subfolder enumeration

```bash
# See top-level folders
curl -s "https://api.target.com/?delimiter=/"

# Explore specific prefix
curl -s "https://api.target.com/?prefix=monitor/&delimiter=/"

# List all objects in a prefix (truncated at 1000)
curl -s "https://api.target.com/?prefix=monitor/apy-leaderboard/accounts/1/"
```

## What to look for

- User wallet/account addresses in folder paths → PII exposure
- Configuration files (`.json`, `.yaml`, `.env`)
- API keys in response bodies
- Internal data: vault positions, market rates, user balances
- Admin panel paths exposed in folder structure

## IPOR Protocol case (Aug 2, 2026)

**Target:** `api.ipor.io`
**Finding:** S3 bucket with public listing enabled
**Exposed:** 1000+ objects including:
- `monitor/apy-leaderboard/accounts/1/0x...` — thousands of user wallet addresses
- `fusion/markets/1/aave-v3/0x...` — vault config per chain (1=Ethereum, 42161=Arbitrum, 8453=Base)
- `fusion/vaults-history/1/0x...` — historical vault state for every vault
- `dapp/plasma-vaults-list` — app configuration
- `data/charts`, `data/ref-rates`, `data/turtle-club-users` — internal data

**Impact:** Information disclosure (wallet addresses + vault positions). S3 bucket listing enables easy enumeration of all data.

**Bounty:** IPOR on Immunefi (slug: `ipor`)
**CORS:** `Access-Control-Allow-Origin: *` on api.ipor.io

## Detection pattern summary

| Signal | What it means |
|--------|--------------|
| Root URL returns XML with `ListBucketResult` | S3 bucket listing ENABLED |
| `?prefix=` and `?delimiter=` work to narrow results | Full bucket exploration possible |
| Server: AmazonS3 header | Confirms S3 hosting |
| No `.json` or `.html` extension on root | Almost certainly S3 bucket root |