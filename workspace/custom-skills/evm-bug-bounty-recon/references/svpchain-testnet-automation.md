# SVP Chain Testnet — Rewards API + Automation (Sep 2026)

## Network
- Chain ID: 2517, RPC: svp-dataseed1-testnet.svpchain.org
- Explorer: explorer.svpchain.com, SVP 18 decimals, gas ~1.7 gwei
- Faucet: POST https://pre-www.svpchain.org/api/claim {address, network:"2517", token:"0x000..."}

## Wallet
- 0xfB34428873a12137aa7502C814a51bAcadF39900 → 1.0000 SVP confirmed

## Rewards API (from JS bundle reverse-engineering)
- Base: https://rewards.svpstars.com/api/v1
- Auth: SiWE (nonce → sign → login → bearer token, 140 bytes)
- Key endpoints: /auth/nonce, /auth/login, /tasks, /social/x/start, /social/x/callback, /tasks/{id}/claim
- Quest dependency: bind_x MUST complete before follow_x, tg_join, discord_join, checkin, quiz unlock

## Quest List
- bind_x: 200pts (claimable immediately) ← GATE for all social quests
- follow_x: 100pts | tg_join: 50pts | discord_join: 50pts | checkin: 20pts | quiz: 30pts
- faucet: 30pts (DONE) | weekly_broadcast: 150pts | deploy_contract: 1000pts

## Automation State
- SiWE auth working, token at /tmp/svp_token.txt
- Script /tmp/svp_x_login.py runs on Kali via Playwright (Chrome Default profile)
- Venv: /tmp/svp_env/ (Playwright + Chromium installed)
- X session EXPIRED on ALL Kali Chrome/Brave profiles → 1x manual login required
- After X login once: cookies persist → all subsequent runs fully automated

## Kali Playwright Caveats
- DISPLAY=:0 REQUIRED (Chromium crashes without X display)
- Profile path must use os.path.expanduser (never hardcoded ~)
- nohup + DISPLAY=:0 can conflict — export DISPLAY in same shell as python3

## SSH File Transfer (banner corruption fix)
- ~/.bashrc banner breaks scp ("Received message too long") AND stdout parsing
- sshd_config Banner disable INSUFFICIENT — banner from .bashrc, not sshd
- Upload: `cat local | sshpass ssh host "bash --noprofile --norc -c 'cat > /dest'"`
- Download: `sshpass ssh host "bash --noprofile --norc -c 'cat /src'" > local`
- ALL remote commands must use: "bash --noprofile --norc -c '...'" wrapper

## MetaMask on Kali
- Chrome Default: extension nkbihfbeogaeaoehlefnkodbefgpgknn
- Brave Profile 5: MetaMask v3.99
- SVP Chain network NOT yet added (Chain ID 2517)
- Maroo wallet PK not imported yet
