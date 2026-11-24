# Escrow Platform Priority List — Bug Bounty Payout Reality (Aug 2026)

> **Why this exists:** Spending weeks on a target that turns out to be email-direct disclosure with no payout is the most common time-sink. Use this list to triage "is this program even worth my time?" in under 2 minutes.

## TL;DR

If the program is not on one of the platforms below, the reward is **not guaranteed, not escrowed, and usually not paid**. Email-direct disclosure addresses (security@vendor.com) without a public Critical/High reward table are a different class of work — treat as free security work, not bug bounty.

## The Pay-out Ladder (verified Aug 2026)

| Platform | Escrow | Typical Critical Cap | Best For | Reality |
|---|---|---|---|---|
| **Cantina** (cantina.xyz) | ✓ (platform) | $1.5M–$15.5M | Live DeFi + web3 (Morpho $2.5M, Ethena $3M, Ondo $1.5M, Uniswap $15.5M, Coinbase $5M) | Cantina-Triaged = most honest triage in the space; deposit required to join (~$20) |
| **Immunefi** (immunefi.com) | ✓ (platform) | $50K–$3M | Live DeFi smart contracts (Ethena $3M, Lombard $250K, SSV $2M, The Graph $200K) | Public program registry, real USDC payouts |
| **Hats Finance** (hats.finance) | ✓ (vault-based) | $50K–$1M+ | DeFi (Sky/Maker, Compound, GMX, etc.) | Decentralized escrow; KYC + public payout in stablecoin |
| **Code4rena** (code4rena.com) | ✓ (platform) | $1K–$250K+ | Audit competitions (time-bounded) | Best for solo hunters: competition format, ~1 week sprints, 2-4 people split pool |
| **Sherlock** (sherlock.xyz) | ✓ (platform) | $50K–$500K+ | Audit competitions (premium tier for vetted auditors) | Invite-only for premium; public contests open |
| **Cantina Competitions** | ✓ (platform) | $30K–$400K | Time-bounded audits (Morpho Midnight $400K) | **Best $$ per hour** if you have specific protocol expertise |
| **HackerOne** (public programs) | ✓ (platform) | $500–$500K | Web/infra (Coinbase, Shopify, etc.) | Mature triage; payouts in bank transfer |
| **Bugcrowd** (public programs) | ✓ (platform) | $500–$200K | Web/infra | Lower per-bug average but consistent volume |
| **Intigriti / YesWeHack** (public) | ✓ (platform) | $500–$150K | Web/infra (EU-heavy) | Smaller, but payouts real and timely |

## Skip Indicators (no real bounty)

- ❌ **"Send to security@vendor.com"** without a public reward table → not a bounty, free disclosure
- ❌ **"Hall of fame" + crypto coin (not USDC/USDC)** → token bounty that may dump to $0
- ❌ **"Kudos points" or "swag only"** → not a paying program
- ❌ **Discord-only triage** with no public SLA → unverifiable, no recourse if ghosted
- ❌ **Lifetime submission cap < 5 reports** → likely a vuln-disclosure inbox, not bounty
- ❌ **"Bug bounty program" with no published Critical payout** → ask, but assume free disclosure

## "How heavy is the audit competition?" — Findings Count Heuristic

A program's "Findings submitted" count (visible on Cantina) is a real metric of how hunted it already is:

| Findings | Reality | Expected Yield from Solo Hunter |
|---|---|---|
| **< 50** | Fresh / low-attention — your window | 1-3 findings, real chance of Critical |
| **50–300** | Active program, normal competition | 1-2 findings, mostly Medium/High |
| **300–1000** | Well-hunted, mid-mature | 0-1 findings, often Low only |
| **> 1000** (Morpho: 1,655) | Mature, heavily audited | 0 findings from quick solo pass; only PoC-grade attack in new code paths |

**Strategy:** prefer **< 50 findings** programs (Ondo Perps 77, Kiln 50, Midas 80, RedStone 50, Uniswap was low). They are still in the realistic critical-finding window. Heavy programs (Morpho 1,655, Pendle 700+, Lombard 165) need specific protocol expertise and weeks of fork PoC.

## "Is the protocol too young to test?" — Audit Age Heuristic

| Code Age | Reality |
|---|---|
| **< 30 days** | Pre-launch contracts often have rushed edge cases; first-depositor / share-inflation still possible |
| **30-180 days** | **Sweet spot** — bugs from first audit cycle may still be live; second wave of hunters finds what the first missed |
| **180-365 days** | Normal hunting ground; expect 1-3 days of recon before first signal |
| **> 365 days** + multiple audits | Hardest — Mature = little low-hanging fruit. Only attack surface is new feature add or new admin operation |

**Strategy:** Look for **programs that just deployed V2** of a previously-audited V1. The V2 migration is where the new attack surface lives, and the audit team is typically focused on the migration code, not the entire V2 codebase.

## Cantina Bounties Currently Live (Aug 2026 snapshot)

| Program | Max Reward | Start Date | Findings | Notes |
|---|---|---|---|---|
| Uniswap Labs | $15.5M USDC | 26 Nov 2024 | high | Mature; reward budget = marketing budget |
| Reserve Protocol | $10M USDC | 27 Mar 2026 | low-medium | New, 5 months in — possible Critical window |
| Euler | $7.5M USDC + rEUL + USUAL | 22 Aug 2024 | 605 | Heavily audited; RWA + EVK + EVC |
| Polymarket | $5M USDC | 13 Apr 2026 | low | Prediction market, new code |
| Coinbase | $5M USDC | 8 Jul 2025 | medium | Web/API focused |
| Morpho | $2.5M USDC | 28 Mar 2024 | 1,655 | Mature, very hard |
| Pendle Finance | $2M USDC | 14 Jun 2024 | 700+ | Mature |
| Ondo Perps | $1.5M USDC | 3 Jun 2026 | 77 | **Sweet spot** — recent, low findings |
| dYdX | $1M USDC | 9 May 2026 | low-medium | Perps, recent |
| Midas.app | $500K USDC | 24 Mar 2026 | low | Recent |
| Kiln | $500K USDC | 9 Sep 2024 | low | OmniVault |
| RedStone | $250K USDC | 1 Nov 2025 | low | Oracle, recent |
| Paxos | $1M USDG (private) | 27 Mar 2026 | private | Invite-only |

## Operational Tips

- **Deposit required (~$20-30)**: Cantina + most Immunefi programs require a deposit to join, refundable from first valid submission. Treat as cost of doing business.
- **KYC**: Many programs require KYC for payout (full name, DOB, address, government ID). Build the KYC packet as a reusable doc.
- **Tax treatment**: Bug bounty income is taxable in most jurisdictions (US, ID). Track payments + program names; in Indonesia this counts as "hadiah" or "penghasilan lain-lain" depending on the volume.
- **Multi-program hunting**: Subscribe to 3-5 programs simultaneously; cycle when one dries up. Don't depend on a single program.

## Decision Tree (60 seconds)

1. **Is the program on Cantina/Immunefi/Hats/Code4rena/H1/Bugcrowd with a public USDC Critical cap?**
   - Yes → proceed (recon next)
   - No (email-direct, no published cap) → **stop, skip**
2. **Findings submitted count?**
   - < 50 → **highest priority**
   - 50–300 → normal priority
   - 300+ → only if you have specific protocol expertise
3. **Critical cap?**
   - ≥ $1M → worth multi-day commitment
   - $50K–$1M → worth 1-day focused pass
   - < $50K → only if quick to recon and high-probability bug class
4. **Scope clear + your bug class covered?**
   - Yes → register + recon
   - No (e.g., SC bug but only web in scope) → pivot to other program
