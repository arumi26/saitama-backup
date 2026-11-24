# skills/m0.md — Skill Registry & Reflection Loop
# Called from AGENTS.md on every session start. Read this first, then route.
# ⚡ CONSOLIDATED July 2026: 59→48 skills via cluster mergers (see CONSOLIDATION NOTES below)

---

## CONSOLIDATION NOTES (v4.2 →, July 2026)

These skills have been merged to reduce loading redundancy. The secondary files still exist with redirect headers — keyword matching still works, just loads the primary file instead.

| Cluster | Merged | Into | Rationale |
|---|---|---|---|
| **Content Creation** | content-creation-strategy-signal-amplification-merged → content-creation-strategy-signal-amplification | content-creation-strategy-signal-amplification (creation+strategy) | Same pipeline: voice/hook/formats + strategy/calendars = one skill |
| **Content Writing** | copywriting-writing-mastery-content-research-analytics-merged → copywriting-writing-mastery-content-research-analytics | copywriting-writing-mastery-content-research-analytics (copy+research) | Writing + analytics = inseparable; research feeds copy, copy needs analytics |
| **Self-Audit** | self-audit-system-refinement-self-improvement-merged → self-audit-system-refinement-self-improvement | self-audit-system-refinement-self-improvement (audit+improvement) | Audit evaluates state, improvement closes the loop — two faces of same meta-system |
| **Strategy** | deep-strategy-problem-shaping-decision-support-merged → deep-strategy-problem-shaping-decision-support | deep-strategy-problem-shaping-decision-support (strategy+shaping) | deep-strategy-problem-shaping-decision-support-merged frames problem at top of funnel, deep-strategy-problem-shaping-decision-support decomposes it — combined thinking pipeline |
| **Debug** | fault-diagnosis-resolution-systematic-debugging-merged → fault-diagnosis-resolution-systematic-debugging | fault-diagnosis-resolution-systematic-debugging (diagnosis+systematic) | fault-diagnosis-resolution-systematic-debugging = fast lookup (known errors), fault-diagnosis-resolution-systematic-debugging-merged = systematic method (unknown bugs) — never used independently |
| **CTF Sub-skills** | ctf-web-exploitation-2—ctf-prompt-injection-llm-red-teaming | dispatched by ctf-whitehat-toolkit-2 | All CTF categories already routed through ctf-whitehat-toolkit-2 — sub-skill files kept for detailed playbooks only |

---

## REGISTRY

Scan table. Match intent. Load matched skill(s) on demand.
Do NOT preload skill files — token cost.

```
ID  | DOMAIN                              | KEYWORDS (high-weight)
----|-------------------------------------|------------------------------------------------
m1  | Monetization & value generation     | monetize, pricing, jual, jualan, cuan, funnel
m2  | Infrastructure & deployment         | VPS, deploy, SSH, nginx, docker, systemd
content-creation-strategy-signal-amplification  | Content creation & distribution (merged content-creation-strategy-signal-amplification-merged) | viral, hook, caption, thread, naskah, konten, content calendar, strategy, pillar, platform adapter, content OS
m4  | Process orchestration & bots        | telegram bot, cron, webhook, n8n, automate, otomatis
m5  | Data transformation & insight       | spreadsheet, excel, csv, dataset, snapshot, laporan
m6  | Protocol binding & service bridge   | API, REST, webhook, midtrans, integrasi
m7  | Inference systems & AI builder      | LLM, prompt, claude API, openrouter, kimi, agent, add model, tambah model, registry model
m8  | File & artifact production          | PDF, DOCX, XLSX, PPTX, generate file, dokumen
m9  | Interface construction              | landing page, react, tailwind, frontend, UI
m10 | Web3 / crypto operations            | wallet, airdrop, on-chain, RPC, ethers, viem, mint
m11 | Security audit & review             | audit, vulnerability, exploit, scam check, malicious
m12 | Batch / parallel operations         | batch, parallel, bulk, mass, queue, worker, snapshot
m13 | Universal NFT minter (any contract) | mint, opensea, manifold, zora, seadrop, NFT, claim, drop
daily-assistant-briefing-alerts-2 | Daily assistant: briefing & alerts  | briefing, ringkasan harian, alert, kabarin kalau, pantau harga, alarm
daily-assistant-ii-watchdog-vault-multimodal-triage | Daily assistant II: watchdog/vault/multimodal/triage | watchdog, restart kalau mati, simpen alamat, macro, voice note, screenshot, triage
m16 | Software engineering & coding       | coding, bikin app, backend, API server, database, testing, scaffold, refactor, golang, rust, fastapi
m17 | Power pack: planner/swarm/automation/backtest/dashboard/voice | rencanain, workflow, otomatis kalau, backtest, dashboard, ngomong, swarm, tim agent
m18 | Creative & media generation         | comfyui, manim, excalidraw, ascii video, slide, design system, diagram, deck
m19 | Desktop & physical control          | isaac sim, omniverse, robot, macos control, applescript, scene, usd, mobility, ros2
m20 | Humanizer & brand voice             | humanizer, brand voice, ai tone, manusiawi, rewrite nada, voice profile
m21 | Enterprise & defensive ops          | KQL, azure, log analytics, sentinel, HIDS, auto firewall, block ip, intrusion
m22 | Scientific & deep research          | deep research, AI-Q, tooluniverse, hipotesis, citations, riset ilmiah, eksperimen
m23 | Executive function & neurodivergent | task breakdown, executive function, ADHD, overwhelmed, fokus, context switch, prioritas
m24 | MCP-builder & prompt engineering    | MCP server, bikin MCP, FastMCP, prompt engineering, fix prompt, audit prompt
m25 | Compliance, CI/CD & code migration  | compliance, regulasi, GDPR, SOC2, CI/CD, pipeline, code migration, port bahasa
m26 | Product & spec workflows            | PRD, to-issues, grill me, spec, user story, TDD, internal comms
content-creation-strategy-signal-amplification-merged | ⚠️ MERGED → content-creation-strategy-signal-amplification (redirect header in file) | REFERENCED: content calendar, content strategy, content pillar, carousel, reels, platform adapter, scroll-stopper
copywriting-writing-mastery-content-research-analytics | Copywriting & content research (merged copywriting-writing-mastery-content-research-analytics-merged) | AIDA, PAS, CHEF, copywriting framework, SEO writing, storytelling, localization, competitor analysis, trend research, social listening, A/B caption, best time post
copywriting-writing-mastery-content-research-analytics-merged | ⚠️ MERGED → copywriting-writing-mastery-content-research-analytics (redirect header in file) | REFERENCED: competitor analysis, trend research, social listening, audience insight, content pipeline, A/B caption, best time post
m30 | Client Revenue Engine (bulk gig, API-first) | client revenue, garapan, bulk gig, harvest, scrape API, anti-browser, mass akun, otomasi job klien, ekstrak data
m31 | Airdrop Intelligence (eligibility/sybil/claim/exit) | eligibility airdrop, skor airdrop, layak airdrop, sybil, anti-sybil, claim window, jadwal claim, kalender airdrop, vesting unlock, exit plan, kapan jual token
ctf-whitehat-toolkit-2 | CTF / Whitehat toolkit                  | CTF, capture the flag, whitehat, bug bounty, decode flag, crypto challenge, caesar, xor cipher, hash identify, forensics, HTB, THM
m33 | Pre-TGE Alpha Radar (deteksi airdrop dini) | alpha airdrop, pre-TGE, points program, testnet incentivized, radar airdrop, proyek belum ada token, worth difarming
m34 | Farming Portfolio & ROI Optimizer       | ROI farming, portfolio airdrop, untung rugi farming, gas vs hasil, farm mana lanjut, drop farming, wallet nganggur
m35 | Auto Guide Studio (panduan otomatis)    | bikin panduan airdrop, tutorial airdrop, guide step by step, artikel airdrop, embed referral
m36 | Tokenomics & Unlock Pressure Engine     | unlock token, vesting, cliff, kalender unlock, sell pressure, tokenomics, jual sebelum unlock
m37 | Anti-Scam Sentinel (brand protection)   | situs palsu, domain palsu, typosquat, phishing airdrop, scam check, warning scam, drainer
m38 | Contract-Change & Claim-Address Watcher | kontrak berubah, proxy upgrade, claim address, aman claim gak, watch kontrak, cek sebelum claim
m39 | Community Intelligence (dengerin komunitas) | topik trending komunitas, sentimen komunitas, FUD, analisis chat, pertanyaan member, ide konten komunitas
m40 | Omni-Repurpose Engine (1 konten → semua) | repurpose konten, ubah jadi thread, carousel IG, script tiktok, script youtube, multi platform
m41 | Video Script-to-Screen Pipeline         | bikin video, script video, storyboard, voiceover, subtitle, srt, reels, youtube video
m42 | Hook A/B Lab + Performance Predictor    | hook, judul konten, headline, a/b test judul, stop scroll, prediksi engagement, varian judul
ctf-web-exploitation-2 | CTF Web Exploitation (sub of ctf-whitehat-toolkit-2)       | CTF web, SQLi, SSTI, SSRF, IDOR, XXE, JWT, deserialization, prototype pollution, race condition
ctf-binary-exploitation-pwn-2 | CTF Binary Exploitation / pwn (sub ctf-whitehat-toolkit-2) | CTF pwn, buffer overflow, ret2win, ret2libc, format string, heap, ROP, pwntools, GOT leak
ctf-reverse-engineering-2 | CTF Reverse Engineering (sub of ctf-whitehat-toolkit-2)    | CTF reverse, angr, symbolic execution, Ghidra, radare2, decompile, keygen, deobfuscation
ctf-cryptography-2 | CTF Cryptography (sub of ctf-whitehat-toolkit-2)           | CTF crypto, RSA attack, Wiener, Hastad, common modulus, Coppersmith, padding oracle, nonce reuse
ctf-forensics-stego-2 | CTF Forensics & Stego (sub of ctf-whitehat-toolkit-2)      | CTF forensics, stego, pcap, memory dump, volatility, binwalk, exiftool, zsteg, steghide
ctf-prompt-injection-llm-red-teaming | CTF Prompt-Injection/LLM (sub of ctf-whitehat-toolkit-2)   | CTF prompt injection, LLM red-team, jailbreak, Gandalf, Lakera, Mosscap, OWASP LLM01, extract system prompt

C1  | Swap & sell via aggregator          | swap, 1inch, jupiter, jual token, sell, DEX
C2  | Cross-chain bridge                  | bridge, LayerZero, stargate, LI.FI, across, hop
C3  | DeFi (lending/staking/perp)         | aave, lido, GMX, hyperliquid, pendle, defi
C4  | Token launch & NFT mint sniping     | snipe, honeypot, PairCreated, GoPlus, sniping
C5  | Whale & mempool tracking            | mempool, whale, nansen, arkham, smart money, tracker
C6  | NFT buy/sell (marketplace)          | beli NFT, blur, magic eden, tensor, reservoir, listing
C7  | Web3 sign-in & typed signing        | SIWE, walletconnect, EIP-712, ENS, permit, EIP-1271
C8  | Browser dApp automation             | buka dapp, browser, playwright, navigate, connect wallet, isi form
C9  | Universal contract read/write       | baca/tulis kontrak, read/write, call fungsi, ABI, inspect, proxy, eksekusi
C10 | Crypto dev: deploy/compile/test     | deploy kontrak, compile, forge, solidity, test, verify, CREATE2, bikin token

self-audit-system-refinement-self-improvement  | Self-audit & self-improvement (merged self-audit-system-refinement-self-improvement-merged) | improve system, self-audit, upgrade brain, self improve, belajar, makin pinter, auto fix, upgrade diri, learn
deep-strategy-problem-shaping-decision-support  | Deep strategy & problem shaping (merged deep-strategy-problem-shaping-decision-support-merged) | strategy, architecture, decompose, plan, design system, problem shaping, brainstorming, sign-off, framing, vague goal, uncertainty
fault-diagnosis-resolution-systematic-debugging  | Fault diagnosis & systematic debug (merged fault-diagnosis-resolution-systematic-debugging-merged) | error, bug, debug, gagal, stack trace, systematic debug, RCA, root cause, hypothesis, intermittent, reproduce
self-audit-system-refinement-self-improvement-merged  | ⚠️ MERGED → self-audit-system-refinement-self-improvement (redirect header in file) | REFERENCED: self improve, belajar, makin pinter, auto fix, upgrade diri, learn
agentic-eval-self-critique-2  | Agentic eval & self-critique        | eval, self-critique, variance, konsistensi, flaky, regression, ukur
fault-diagnosis-resolution-systematic-debugging-merged  | ⚠️ MERGED → fault-diagnosis-resolution-systematic-debugging (redirect header in file) | REFERENCED: systematic debug, RCA, root cause, hypothesis, intermittent, reproduce
deep-strategy-problem-shaping-decision-support-merged  | ⚠️ MERGED → deep-strategy-problem-shaping-decision-support (redirect header in file) | REFERENCED: problem shaping, brainstorming, sign-off, framing, vague goal, uncertainty
```

### Skill marketplace (skills.sh) — opsional, PARANOID
Skill pihak ketiga masuk lewat `tools/skill_market.py` → **quarantine**, BUKAN auto-aktif.
Wajib audit (m11) → operator pindah ke `skills/` → `skill_integrity.py generate` (re-lock).
Tidak pernah auto-install + auto-activate. Sama prinsip self-audit-system-refinement-self-improvement-merged: friksi = fitur.

---

## ROUTING

```
0 matches:     answer from core knowledge — load nothing
1 match:       load full skill file
2+ matches:    pick PRIMARY (highest score), load it fully
               pull SUPPORTING (>50% of primary's score) section-by-section
ambiguous tie: ask once — "Fokus ke [A] atau [B] dulu?"
H-skill hit:   load skills/onchain-execution/DISPATCH.md FIRST, then specific reference
```

### MUSE routing
C1-C7 are NOT standalone files. They map to `skills/onchain-execution/references/*.md`:
```
C1 → skills/onchain-execution/references/swap.md
C2 → skills/onchain-execution/references/bridge.md
C3 → skills/onchain-execution/references/defi.md
C4 → skills/onchain-execution/references/sniping.md
C5 → skills/onchain-execution/references/monitoring.md (advanced sections 8-11)
C6 → skills/onchain-execution/references/nft.md
C7 → skills/onchain-execution/references/web3_connect.md
```
Load `muse/DISPATCH.md` once per session if any H-skill fires (caches env var check + safety rails). Then load specific reference. Combine with m10/m12/m13 if task overlaps.

---

## REFLECTION LOOP

Runs silently after every output. Non-negotiable.

```
✅ Immediately executable / usable as-is?
✅ Anything the operator will need next that's missing?
✅ Generic advice — could be replaced with operator-specific code?
✅ Faster or cleaner path missed?
✅ Did I include the run command / deploy step?
✅ Token usage justified — could same value land in fewer lines?
```

Any fail → revise BEFORE outputting.
Upgrade exists → append: `🔧 Upgrade: [one line]`

---

## REFLECTION ESCAPE HATCH

If reflection loop catches issue but fix would 2x the response length → ship the working version, append:
> `🔧 Bisa di-upgrade ke [X]. Mau elaborasi?`

**Load when:** skills/m0.md — Skill Registry & Reflection Loop
