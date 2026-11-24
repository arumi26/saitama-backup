# Telegram Group Discovery — Blocked Search Engine Workaround

## Problem
All headless search engines block headless curl requests with empty/no results:
- DuckDuckGo HTML → 0 results (Cloudflare bot detection)
- Bing HTML → 0 results (SPA redirect, no HTML content)
- Brave → 0 results (SPA redirect)
- Yandex → 0 results
- Qwant → 0 results
- searchg.app → 0 bytes (requires JS rendering)
- tgstat.ru → empty response
- telega.io → empty response
- TelegramDB → empty response
- Telegram Channels → empty response

**Root cause:** Modern search engines require JavaScript rendering. Headless curl without a real browser driver gets blocked or served empty pages.

**Hermes browser daemon:** Also broken (CDP connection refused, missing Chromium libs). Cannot use `browser_navigate` for Telegram search.

## Solution: Direct @channel Enumeration

### Method
Enumerate likely Telegram channel/group slugs directly via `curl t.me/{slug}`. This bypasses search engines entirely.

### Commands

```bash
# Check if a Telegram channel/group exists and get member count
curl -sL --max-time 3 -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" \
  "https://t.me/{CHANNEL_SLUG}" 2>&1

# Extract member count
curl -sL --max-time 3 -H "User-Agent: Mozilla/5.0" "https://t.me/{CHANNEL_SLUG}" \
  | grep -oP 'tgme_page_extra.*?(\d+\s*(member|members|subscriber|subscribers))' \
  | grep -oP '\d+'

# Extract title and description
curl -sL --max-time 3 -H "User-Agent: Mozilla/5.0" "https://t.me/{CHANNEL_SLUG}" \
  | grep -oP '<title>(.*?)</title>'
curl -sL --max-time 3 -H "User-Agent: Mozilla/5.0" "https://t.me/{CHANNEL_SLUG}" \
  | grep -oP 'og:description.*?content="([^"]*)"'

# Batch enumerate multiple channels
for channel in "AI_agent" "AI_agents" "AI_Agent_Crypto" "AI_agents_global"; do
  result=$(curl -sL --max-time 2 -H "User-Agent: Mozilla/5.0" "https://t.me/$channel")
  if echo "$result" | grep -q 'tgme_page'; then
    members=$(echo "$result" | grep -oP 'tgme_page_extra.*?(\d+\s*member[^s])' | grep -oP '\d+' | head -1)
    if [ -n "$members" ] && [ "$members" -gt 50 ] 2>/dev/null; then
      title=$(echo "$result" | grep -oP '<title>(.*?)</title>' | sed 's/<title>//;s/<\/title>//')
      echo "t.me/$channel — $members members — $title"
    fi
  fi
done
```

### Keyword Lists for Enumeration

#### Generic AI Agent keywords
```
AI_agent AI_agents AI_Agent_AI AI_Agent_Crypto AI_agent_web3
AI_agent_bot AI_agent_group AI_agent_community AI_agent_chat
AutonomousAgents AI_agent_research AI_agent_platform
AI_agent_network AI_agent_protocol AI_agent_data AI_agent_compute
AI_agent_inference AI_agent_training AI_agent_model
```

#### Crypto/Web3 AI Agent keywords
```
AI_agent_crypto AI_agent_defi AI_agent_dex AI_agent_bridg
AI_agent_exchange AI_agent_trading AI_agent_mining
AI_agent_airdrop AI_agent_points AI_agent_rewards
AI_agent_earn AI_agent_farm AI_agent_play2earn AI_agent_mint
```

#### Popular AI Agent Project keywords
```
FetchAI fetai FETAI ASI_Alliance Autonolas OceanProtocol
rendernetwork RNDR_Official Bittensor TAO_Network
agentlayer AgentLayer agentfi AgentFi
aiagentcommunity AItools AI_Miner
```

### Verification
- If response contains `tgme_page` → channel/group EXISTS
- If response contains `This channel is empty` → exists but no posts
- If response contains `group doesn't exist` or `This page is a part of` → doesn't exist
- If response is empty or 0 bytes → blocked or rate-limited
- Member count extracted from `tgme_page_extra` element

### Known Working Channels (verified August 2026)
| Slug | Members | Type | Focus |
|------|---------|------|-------|
| agents_lab | 876 | Chat | AI Agents discussion (RU/EN) |
| Web3AIAgents | 480 | Channel | AI Agents in Web3/Crypto |
| swarm_base | 361 | Channel | SwarmBase official (AI Agent platform) |
| agentnetwork | 452 | Group | Real estate (not AI despite name) |
| aiagentcommunity | 116 | Channel | AI Agent token/community |

### Caveats
- Rate-limited: ~2-3 channels/second max before Telegram blocks
- Small channels (<50 members) may not appear in bulk scan
- t.me/s/ (search pages) returned 0 members for all "AI agent" keywords
- No member count or description for private channels
- Requires valid User-Agent header (Telegram blocks default curl UA)
- Cross-reference Twitter bio and website footer for official links

### Alternative Approaches (when t.me enumeration is blocked)
1. **Use browser automation** — `browser_navigate` to `https://t.me/search?query=AI+agent`
2. **Use Telegram API** — Bot token with `searchChatsOnline` method
3. **Use Telegram Desktop** — Search within the desktop app
4. **Use third-party directories** — tgstat.ru, telega.io (but these also block headless)
