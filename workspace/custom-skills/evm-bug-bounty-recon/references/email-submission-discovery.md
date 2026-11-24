# Email-Based Bug Bounty Submission Discovery

## Technique: `.well-known/security.txt` Scanning

When Immunefi/HackerOne/Bugcrowd require KYC, have low payouts, or only accept smart contract bugs (not web2 findings), use **security.txt scanning** to find programs that accept direct email submissions.

### Batch Scan Command

```bash
for domain in \
  "opensea.io" "coinbase.com" "kraken.com" "binance.com" \
  "across.to" "vercel.com" "linear.app" "discord.com" \
  "metamask.io" "trustwallet.com" "worldcoin.org" "proton.me" \
  "signal.org" "trezor.io" "posthog.com" "clerk.com" \
  "1password.com" "auth0.com" "asana.com" "zoom.us" \
  "netlify.com" "mixpanel.com" "amplitude.com" "monday.com"; do
  result=$(curl -s --max-time 5 "https://${domain}/.well-known/security.txt" 2>/dev/null)
  if echo "$result" | grep -qi "mailto:\|security@"; then
    email=$(echo "$result" | grep -oP 'mailto:\K[^\s;]+' | head -1)
    echo "✅ $domain -> $email"
  fi
done
```

### Confirmed Email Programs (Aug 2026)

| Domain | Email | Max Bounty |
|--------|-------|-----------|
| across.to | bugs@across.to | $1,000,000 |
| opensea.io | security@opensea.io | Unknown (Bugcrowd) |
| metamask.io | metamask.security@consensys.net | Unknown |
| vercel.com | responsible.disclosure@vercel.com | Unknown |
| linear.app | security@linear.app | Unknown |
| discord.com | bugbounty@discordapp.com | Unknown |
| trezor.io | security@satoshilabs.com | Unknown |
| worldcoin.org | security@world.org | Unknown |
| 1password.com | security@agilebits.com | Unknown |
| proton.me | security@proton.me | Unknown |
| signal.org | security@signal.org | Unknown |
| clerk.com | security@clerk.dev | Unknown |
| auth0.com | security@okta.com | Unknown |
| posthog.com | security-reports@posthog.com | Unknown |
| asana.com | security@asana.com | Unknown |
| zoom.us | security-reports@zoom.us | Unknown |

### When to Use Email Submission

1. DeFi/web3 protocols with Immunefi programs that only cover smart contracts
2. Web2 findings (CORS, API key leaks, S3 exposure, XSS, IDOR) that are OOS on Immunefi
3. Programs with no KYC requirement (email-based)
4. Programs where you already have confirmed findings but no platform to submit

### Across.to Case Study (Aug 2026)

- Policy: https://docs.across.to/introduction/bug-bounty
- Email: bugs@across.to
- Max bounty: $1,000,000
- Severity: Low $250, Medium $1,000, High $10,000, Critical up to $1,000,000
- Scope: ALL smart contracts + off-chain code (across-protocol repo)
- 0 hacks, $37B volume, Vercel+Cloudflare, properly secured
- Web2 findings on this target: CORS: * on 4 domains, CSP report-only, testnet public

### Submission Format (from Across.to policy)

```
Description: High-level description with links to problematic code
Attack: Detailed instructions for exploiting the bug
Mitigation: How to resolve the bug
Suggested risk rating: Recommended severity
```