# Email Security Audit - Pivot When WAF Blocks Everything

When Cloudflare Turnstile or aggressive WAF blocks all web testing, pivot to email/DNS security checks. These often produce accepted bug bounty findings without needing to access the web application.

## Quick Checks

```bash
# SPF Check - Missing = email spoofing possible (MEDIUM)
dig +short TXT example.com | grep -i spf

# DMARC Check - Missing = no policy enforcement (MEDIUM)
dig +short TXT _dmarc.example.com

# DKIM Check (common selectors)
for sel in google default mail selector1 selector2 k1; do
    result=$(dig +short TXT ${sel}._domainkey.example.com 2>/dev/null)
    [ -n "$result" ] && echo "$sel: found"
done

# CAA Check - Missing = any CA can issue certs (LOW)
dig +short CAA example.com

# DNSSEC Check - Missing = DNS spoofing possible (LOW)
dig +short DS example.com

# MTA-STS Check (LOW)
curl -s "https://mta-sts.example.com/.well-known/mta-sts.txt"

# BIMI Check (INFORMATIONAL)
dig +short TXT default._bimi.example.com
```

## Severity Guide

| Finding | Severity | Est. Reward (IDR) |
|---------|----------|-------------------|
| Missing SPF + DMARC combo | Medium | Rp 500k-1jt |
| Missing SPF only | Medium | Rp 500k-1jt |
| Missing DMARC only | Low-Medium | Rp 300-500k |
| Missing CAA | Low | Rp 200-500k |
| No DNSSEC | Low | Rp 200-500k |
| No MTA-STS | Low | Rp 100-300k |

## Impact Statement for Reports

**Missing SPF + DMARC:**
> The combination of missing SPF and DMARC records creates a significant email security vulnerability. An attacker can send emails appearing to originate from any @target.com address, enabling phishing attacks against customers, Business Email Compromise (BEC) attacks, and brand reputation damage.

## Remediation Suggestions

```
SPF:     example.com.        IN TXT "v=spf1 include:_spf.google.com ~all"
DMARC:   _dmarc.example.com. IN TXT "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com; pct=100"
CAA:     example.com.        IN CAA 0 issue "letsencrypt.org"
         example.com.        IN CAA 0 iodef "mailto:security@example.com"
```

## Case Study: redstorm.io (2026-07-14)

Target completely blocked by Cloudflare Turnstile - all bypass attempts failed:
- nodriver + WARP: CF challenge never resolved
- CloakBrowser + proxy: Still blocked
- CloakBrowser headless=False + humanize: Still blocked

Pivot to email security produced 5 findings:
1. Missing SPF (Medium)
2. Missing DMARC (Medium)
3. Missing CAA (Low)
4. No DNSSEC (Low)
5. No MTA-STS (Low)

## CF Turnstile Bypass Attempts (For Reference)

When CF Turnstile blocks, these were tried:
1. **nodriver** - stealth chromium, often fails on strict Turnstile
2. **CloakBrowser** (`pip install cloakbrowser`) - 66 C++ patches, better than nodriver
3. **WARP** - Cloudflare's own VPN, sometimes helps
4. Residential proxy with geoip matching
5. headless=False with Xvfb + humanize=True

If all fail after 2-3 attempts, pivot to passive recon (email/DNS security, Wayback, crt.sh subdomains).

## WARP CLI Setup (Headless)

```bash
# Install
curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor -o /usr/share/keyrings/cloudflare-warp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/cloudflare-warp-archive-keyring.gpg] https://pkg.cloudflareclient.com/ $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
sudo apt-get update && sudo apt-get install -y cloudflare-warp

# Accept TOS in headless (no TTY) - use script to simulate
script -q -c "echo y | warp-cli registration new" /dev/null
warp-cli mode warp
warp-cli connect
warp-cli status  # Should show "Connected"
```
