# Self-Hosted Bug Bounty Programs (July 2026)

## Source
`karemelsqary/self-hosted-bug-bounty-programs` — verified list compiled 2026-07-20.

## Top Self-Hosted Programs (Pay Cash)

### Big Tech
| Program | URL | Contact | Max Bounty |
|---------|-----|---------|------------|
| Google VRP | https://bughunters.google.com/ | security@google.com | $100K+ |
| Microsoft MSRC | https://msrc.microsoft.com/bounty | web form | $100K+ |
| Apple Security | https://security.apple.com/bounty/ | web form | $100K+ |
| Meta Whitehat | https://bugbounty.meta.com/ | web form | $50K+ |
| Mozilla | https://www.mozilla.org/security/bug-bounty/ | security@mozilla.org | $10K |

### Crypto/Finance (High Payout, Less Competition)
| Program | URL | Contact | Max Bounty |
|---------|-----|---------|------------|
| Kraken | https://www.kraken.com/features/security/bug-bounty | bugbounty@kraken.com | $100K+ |
| Ledger Donjon | https://donjon.ledger.com/bounty/ | web form | $50K+ |
| Proton | https://proton.me/security/bug-bounty | security@proton.me | $10K |

### SaaS/Tech (Medium Payout, Less Competition)
| Program | URL | Contact | Max Bounty |
|---------|-----|---------|------------|
| Zoho Corp | https://bugbounty.zohocorp.com/bb/info | security@zohocorp.com | $5K |
| Open Collective | https://docs.opencollective.com/help/product/security | security@opencollective.com | $500 |
| Telegram | https://core.telegram.org/bug-bounty | security@telegram.org | $100K |

### Hardware/Mobile
| Program | URL | Contact | Max Bounty |
|---------|-----|---------|------------|
| Samsung Mobile | https://security.samsungmobile.com/ | mobile.security@samsung.com | $20K |
| Samsung TV | https://samsungtvbounty.com/ | secbugbounty@samsung.com | $10K |
| Huawei HBP | https://bugbounty.huawei.com/ | psirt@huawei.com | $10K |

### Asian Tech
| Program | URL | Contact | Max Bounty |
|---------|-----|---------|------------|
| Naver | https://bugbounty.naver.com/ | dl_naverbugbounty@navercorp.com | $10K |
| Alibaba ASRC | https://security.alibaba.com/ | security-response@service.alibaba.com | $10K |
| Tencent TSRC | https://en.security.tencent.com/ | security@tencent.com | $10K |
| ByteDance | https://src.bytedance.com/ | security@bytedance.com | $10K |
| Bilibili | https://security.bilibili.com/ | security@bilibili.com | $5K |
| Trip.com | https://src.trip.com/ | src@trip.com | $5K |

## Independent Programs (Less Competition, Faster Response)

Source: `lissy93/bug-bounties` — 3,000+ programs, `independent-programs.yml`

| Program | URL | Contact | Max Bounty | Response |
|---------|-----|---------|------------|----------|
| atmail.com | https://www.atmail.com/bug-bounty-terms/ | security@atmail.com | $5K | 10 days |
| Bambu Lab | https://bambulab.com/en/bug-bounty-program | security@bambulab.com | $5K | 10 days |
| aurasell.ai | https://www.aurasell.ai/bug-bounty | security@aurasell.ai | $1K | 2 days |
| bentley.com | https://www.bentley.com/legal/bug-bounty-report/ | web form | $1K | 90 days |

## Atmail.com Recon Results (July 31, 2026)
- **Technology**: WordPress + Yoast SEO v28.1
- **CDN**: Cloudflare (WAF blocking .env, .git, wp-admin)
- **Subdomains**: www, api, static (CloudFront)
- **WP-JSON API**: Accessible for public endpoints (posts, pages, comments, categories, tags, media)
- **Protected endpoints**: users (401), settings (401), plugins (401), themes (401)
- **Security**: GOOD — Cloudflare blocking most attacks, API properly secured
- **Recommendation**: Pivot to aurasell.ai (less competition, faster response)
