# Skill Registry & Reflection Loop

**Category:** Core

**Load when:** skill-registry-reflection-loop
## REGISTRY

Scan table. Match intent. Load matched skill(s) on demand.
Do NOT preload skill files — token cost.

```
ID  | DOMAIN                              | KEYWORDS (high-weight)
----|-------------------------------------|------------------------------------------------
value-generation-monetization  | Monetization & value generation     | monetize, pricing, jual, jualan, cuan, funnel
infrastructure-deployment  | Infrastructure & deployment         | VPS, deploy, SSH, nginx, docker, systemd
content-creation-distribution  | Content creation & distribution     | viral, hook, caption, thread, naskah, konten
process-orchestration-bots  | Process orchestration & bots        | telegram bot, cron, webhook, n8n, automate, otomatis
data-transformation-insight  | Data transformation & insight       | spreadsheet, excel, csv, dataset, snapshot, laporan
protocol-binding-service-bridge  | Protocol binding & service bridge   | API, REST, webhook, midtrans, integrasi
inference-systems-ai-builder  | Inference systems & AI builder      | LLM, prompt, claude API, openrouter, kimi, agent, add model, tambah model, registry model
file-artifact-production  | File & artifact production          | PDF, DOCX, XLSX, PPTX, generate file, dokumen
interface-construction  | Interface construction              | landing page, react, tailwind, frontend, UI
web3-on-chain-operations | Web3 / crypto operations            | wallet, airdrop, on-chain, RPC, ethers, viem, mint
security-audit-review | Security audit & review             | audit, vulnerability, exploit, scam check, malicious
batch-parallel-operations | Batch / parallel operations         | batch, parallel, bulk, mass, queue, worker, snapshot
universal-nft-minter | Universal NFT minter (any contract) | mint, opensea, manifold, zora, seadrop, NFT, claim, drop
daily-assistant-briefing-alerts | Daily assistant: briefing & alerts  | briefing, ringkasan harian, alert, kabarin kalau, pantau harga, alarm
daily-assistant-ii-watchdog-vault-triage | Daily assistant II: watchdog/vault/multimodal/triage | watchdog, restart kalau mati, simpen alamat, macro, voice note, screenshot, triage
software-engineering-coding | Software engineering & coding       | coding, bikin app, backend, API server, database, testing, scaffold, refactor, golang, rust, fastapi
power-pack-planner-swarm-automation | Power pack: planner/swarm/automation/backtest/dashboard/voice | rencanain, workflow, otomatis kalau, backtest, dashboard, ngomong, swarm, tim agent
creative-media-generation | Creative & media generation         | comfyui, manim, excalidraw, ascii video, slide, design system, diagram, deck
desktop-physical-control | Desktop & physical control          | isaac sim, omniverse, robot, macos control, applescript, scene, usd, mobility, ros2
humanizer-brand-voice | Humanizer & brand voice             | humanizer, brand voice, ai tone, manusiawi, rewrite nada, voice profile
enterprise-defensive-ops | Enterprise & defensive ops          | KQL, azure, log analytics, sentinel, HIDS, auto firewall, block ip, intrusion
scientific-deep-research | Scientific & deep research          | deep research, AI-Q, tooluniverse, hipotesis, citations, riset ilmiah, eksperimen
executive-function-neurodivergent | Executive function & neurodivergent | task breakdown, executive function, ADHD, overwhelmed, fokus, context switch, prioritas
mcp-builder-prompt-engineering | MCP-builder & prompt engineering    | MCP server, bikin MCP, FastMCP, prompt engineering, fix prompt, audit prompt
compliance-ci-cd-code-migration | Compliance, CI/CD & code migration  | compliance, regulasi, GDPR, SOC2, CI/CD, pipeline, code migration, port bahasa
product-spec-workflows | Product & spec workflows            | PRD, to-issues, grill me, spec, user story, TDD, internal comms
content-strategy-social-media | Content strategy & social media     | content calendar, content strategy, content pillar, carousel, reels, platform adapter, scroll-stopper
copywriting-writing-mastery | Copywriting & writing mastery       | AIDA, PAS, CHEF, copywriting framework, SEO writing, storytelling, localization, multilingual
content-research-analytics | Content research, analytics & pipeline | competitor analysis, trend research, social listening, audience insight, content pipeline, A/B caption, best time post
client-revenue-engine | Client Revenue Engine (bulk gig, API-first) | client revenue, garapan, bulk gig, harvest, scrape API, anti-browser, mass akun, otomasi job klien, ekstrak data
airdrop-intelligence | Airdrop Intelligence (eligibility/sybil/claim/exit) | eligibility airdrop, skor airdrop, layak airdrop, sybil, anti-sybil, claim window, jadwal claim, kalender airdrop, vesting unlock, exit plan, kapan jual token
ctf-whitehat-toolkit | CTF / Whitehat toolkit                  | CTF, capture the flag, whitehat, bug bounty, decode flag, crypto challenge, caesar, xor cipher, hash identify, forensics, HTB, THM
pre-tge-alpha-radar | Pre-TGE Alpha Radar (deteksi airdrop dini) | alpha airdrop, pre-TGE, points program, testnet incentivized, radar airdrop, proyek belum ada token, worth difarming
farming-portfolio-roi-optimizer | Farming Portfolio & ROI Optimizer       | ROI farming, portfolio airdrop, untung rugi farming, gas vs hasil, farm mana lanjut, drop farming, wallet nganggur
auto-guide-studio | Auto Guide Studio (panduan otomatis)    | bikin panduan airdrop, tutorial airdrop, guide step by step, artikel airdrop, embed referral
tokenomics-unlock-pressure-engine | Tokenomics & Unlock Pressure Engine     | unlock token, vesting, cliff, kalender unlock, sell pressure, tokenomics, jual sebelum unlock
anti-scam-sentinel | Anti-Scam Sentinel (brand protection)   | situs palsu, domain palsu, typosquat, phishing airdrop, scam check, warning scam, drainer
contract-change-claim-address-watcher | Contract-Change & Claim-Address Watcher | kontrak berubah, proxy upgrade, claim address, aman claim gak, watch kontrak, cek sebelum claim
community-intelligence | Community Intelligence (dengerin komunitas) | topik trending komunitas, sentimen komunitas, FUD, analisis chat, pertanyaan member, ide konten komunitas
omni-repurpose-engine | Omni-Repurpose Engine (1 konten → semua) | repurpose konten, ubah jadi thread, carousel IG, script tiktok, script youtube, multi platform
video-script-to-screen-pipeline | Video Script-to-Screen Pipeline         | bikin video, script video, storyboard, voiceover, subtitle, srt, reels, youtube video
hook-a-b-lab | Hook A/B Lab + Performance Predictor    | hook, judul konten, headline, a/b test judul, stop scroll, prediksi engagement, varian judul
ctf-web-exploitation | CTF Web Exploitation (sub of ctf-whitehat-toolkit)       | CTF web, SQLi, SSTI, SSRF, IDOR, XXE, JWT, deserialization, prototype pollution, race condition
ctf-binary-exploitation-pwn | CTF Binary Exploitation / pwn (sub ctf-whitehat-toolkit) | CTF pwn, buffer overflow, ret2win, ret2libc, format string, heap, ROP, pwntools, GOT leak
ctf-reverse-engineering | CTF Reverse Engineering (sub of ctf-whitehat-toolkit)    | CTF reverse, angr, symbolic execution, Ghidra, radare2, decompile, keygen, deobfuscation
ctf-cryptography | CTF Cryptography (sub of ctf-whitehat-toolkit)           | CTF crypto, RSA attack, Wiener, Hastad, common modulus, Coppersmith, padding oracle, nonce reuse
ctf-forensics-stego | CTF Forensics & Stego (sub of ctf-whitehat-toolkit)      | CTF forensics, stego, pcap, memory dump, volatility, binwalk, exiftool, zsteg, steghide
ctf-prompt-injection-llm-red-team | CTF Prompt-Injection/LLM (sub of ctf-whitehat-toolkit)   | CTF prompt injection, LLM red-team, jailbreak, Gandalf, Lakera, Mosscap, OWASP LLM01, extract system prompt
team-orchestration-multi-user-ops | Team Orchestration & Multi-User Ops  | team, tim, anggota, collaboration, delegate, assign, task routing, multi-user, role, billing split, assign task, client management
autonomous-monetization-engine | Autonomous Monetization Engine       | monetize, revenue, profit, earning, income, treasury, yield, P&L, cashflow, auto-revenue, passive income, profit report, money maker
offensive-security-red-team-ops | Offensive Security & Red-Team Ops    | offensive, red-team, adversary, exploit dev, backdoor, payload, C2, implant, post-exploit, persistence, lateral movement, exfil, opsec

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

self-audit-system-refinement  | Internal capability refinement      | improve system, self-audit, upgrade brain
deep-decomposition-strategy  | Deep decomposition & strategy       | strategy, architecture, decompose, plan, design system
fault-diagnosis-resolution  | Fault diagnosis & resolution        | error, bug, debug, gagal, rusak, stack trace
self-improvement-autonomous-fix  | Self-improvement & autonomous fix   | self improve, belajar, makin pinter, auto fix, upgrade diri, learn
agentic-eval-self-critique  | Agentic eval & self-critique        | eval, self-critique, variance, konsistensi, flaky, regression, ukur
systematic-debug-auto-debug  | Systematic debug & auto-debug loop  | systematic debug, RCA, root cause, hypothesis, intermittent, reproduce
problem-shaping-decision-support  | Problem shaping & decision support  | problem shaping, brainstorming, sign-off, framing, vague goal, uncertainty
```

### NEW SKILLS (team-orchestration-multi-user-ops–offensive-security-red-team-ops)

**team-orchestration-multi-user-ops — Team Orchestration & Multi-User Ops**: team delegation (Level 0–3 routing), task assignment tracking, per-member billing attribution, conflict detection & resolution, client management dashboard, multi-session awareness, role-based access control. → `skills/library/team-orchestration-multi-user-ops.md`

**autonomous-monetization-engine — Autonomous Monetization Engine**: treasury management, cashflow tracking, P&L generation, revenue stream optimization, auto-revenue strategies (MEV, airdrop, yield, NFT flip), cost optimization, profit reporting (daily/weekly/monthly), passive income pipeline maintenance. → `skills/library/autonomous-monetization-engine.md`

**offensive-security-red-team-ops — Offensive Security & Red-Team Ops**: exploit development lifecycle (research → PoC → weaponize), C2 infrastructure (Cobalt Strike/Mythic/Sliver patterns), post-exploitation (persistence, lateral movement, privilege escalation), payload generation (shellcode, DLL hijacking, process injection), operational security (OPSEC), adversary simulation (MITRE ATT&CK mapping), red-team infrastructure design, phishing & social engineering frameworks. → `skills/library/offensive-security-red-team-ops.md`

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
C1-C10 are NOT standalone files. They map to `skills/onchain-execution/references/*.md`:
```
C1 → skills/onchain-execution/references/swap.md       C2 → skills/onchain-execution/references/bridge.md
C3 → skills/onchain-execution/references/defi.md       C4 → skills/onchain-execution/references/sniping.md
C5 → skills/onchain-execution/references/monitoring.md  C6 → skills/onchain-execution/references/nft.md
C7 → skills/onchain-execution/references/web3_connect.md C8 → skills/onchain-execution/references/browser.md
C9 → skills/onchain-execution/references/contract_read.md + contract_write.md
C10 → skills/onchain-execution/references/deploy.md
```
Load `muse/DISPATCH.md` once per session if any H-skill fires.

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
✅  Does this generate value or move the profit needle?
✅  Can this scale to the team?
```

Any fail → revise BEFORE outputting.
Upgrade exists → append: `🔧 Upgrade: [one line]`
Revenue applicable → append: `💸 Revenue: [estimated impact]`

---

## REFLECTION ESCAPE HATCH

If reflection loop catches issue but fix would 2x the response length → ship the working version, append:
> `🔧 Bisa di-upgrade ke [X]. Mau elaborasi?`

---

## AUTONOMOUS SCAN 

After every reflection loop, scan autonomous triggers table from AGENTS.md.
If any trigger fires → auto-execute in background, log to memory.
Push exceptions to next briefing.
