# Bug Bounty Skill Installation from rickyananda/hermes-skills

## Source
GitHub: https://github.com/rickyananda/hermes-skills

## Installation Method
Skills di repo ini bukan bundled (Hermes shipped). Harus di-copy manual:

```bash
# Clone repo
cd /tmp && git clone --quiet https://github.com/rickyananda/hermes-skills 2>/dev/null

# Copy skills to local directory
SKILL_SRC="/tmp/hermes-skills"
SKILL_DEST="/home/ubuntu/.hermes/skills"

# Bug bounty & red teaming
mkdir -p "$SKILL_DEST/red-teaming"
cp -r "$SKILL_SRC/red-teaming/galaxy-bugbounty-checklist" "$SKILL_DEST/red-teaming/"
cp -r "$SKILL_SRC/red-teaming/web-recon-bugbounty" "$SKILL_DEST/red-teaming/"
cp -r "$SKILL_SRC/red-teaming/ssrf-scanner" "$SKILL_DEST/red-teaming/"
cp -r "$SKILL_SRC/red-teaming/hackingtool" "$SKILL_DEST/red-teaming/"
cp -r "$SKILL_SRC/red-teaming/godmode" "$SKILL_DEST/red-teaming/"
cp -r "$SKILL_SRC/red-teaming/mimo-jailbreak" "$SKILL_DEST/red-teaming/"

# Crypto research
mkdir -p "$SKILL_DEST/crypto"
cp -r "$SKILL_SRC/crypto/crypto-airdrop-research" "$SKILL_DEST/crypto/"
```

## Dependencies
- **web-recon-bugbounty:** `pip3 install dnspython requests`
- **ssrf-scanner:** `git clone https://github.com/Dancas93/SSRF-Scanner`, venv + pip install requirements
- **hackingtool:** Manual install via GitHub (interactive menu, needs sudo)

## Note
- Repo ini adalah **community collection**, bukan official Hermes repo
- Skill di repo ini perlu di-install manual (tidak auto-loaded)
- Install via `cp -r` ke `~/.hermes/skills/<category>/`
