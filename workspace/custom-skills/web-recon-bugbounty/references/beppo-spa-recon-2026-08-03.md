# Beppo.space SPA Recon Pattern

## Target
Beppo.space — "5,555 whitelist event on ETH. Connect X, raid, refer, and open boxes for a shot at GTD spots and NFTs."

## Architecture
- **Frontend:** React + Vite SPA (Vitest test framework detected in bundle)
- **Backend API:** `https://beppo-api.onrender.com` (Render-hosted Express.js)
- **Auth:** Token-based (localStorage: `beppo_token`), X (Twitter) integration
- **Admin Panel:** `/admin` route, token stored in `localStorage.getItem("beppo_admin_token")`, basic auth (username/password form)
- **Admin routes:** `/admin/overview`, `/admin/tasks`, `/admin/users`, `/admin/raids`, `/admin/walletRequests`, `/admin/pools`, `/admin/settings`, `/admin/megapool`, `/admin/opens`, `/admin/login`
- **Task types:** `{tasks, users, raids, walletRequests, pools, settings, overview, megapool, opens}`

## API Endpoints Discovered

| Method | Endpoint | Auth Required | Description |
|--------|----------|---------------|-------------|
| GET | `/campaign` | No | Campaign status, day count, reset times |
| GET | `/leaderboard` | No | Top 20 users by points, max points |
| GET | `/pools/today` | No | GTD/FCFS pool status, remaining counts |
| GET | `/megapool/status` | Yes (beppo_token) | Megapool user status |
| GET | `/me` | Yes (beppo_token) | Current user profile |
| GET | `/raids` | Yes (beppo_token) | Raid tasks |
| POST | `/box/open` | Yes (beppo_token) | Open a mystery box |
| POST | `/megapool/enter` | Yes (beppo_token) | Enter megapool |
| POST | `/wallet` | Yes (beppo_token) | Wallet operations |
| POST | `/wallet/change-request` | Yes (beppo_token) | Change wallet address |
| POST | `/dev/login` | Yes (beppo_token) | Dev login endpoint |
| POST | `/admin/login` | No | Admin authentication (basic auth) |

## Admin Panel
- **URL:** Accessible at `/admin` (same domain as API or frontend)
- **Auth:** Simple username/password form
- **Session token:** `beppo_admin_token` stored in localStorage
- **Request header:** `x-admin-token` header included on admin API calls
- **Sections:** overview, tasks, users, raids, walletRequests, pools, settings, megapool, opens

## Event Mechanics

### Points System
- Users earn points through X (Twitter) interactions:
  - Connect X account → join raids
  - Follow/retweet/quote X posts
  - Referral program
- Points determine WL ranking on leaderboard

### Box Opening (Mystery Box)
- Users earn "boxes" through point accumulation
- Boxes have outcomes: `gtd` (guaranteed), `fcfs` (first come first serve), `points_back`, `dud`
- Opening boxes uses POST `/box/open`
- Megapool combines pool entries: POST `/megapool/enter`

### Campaign Structure
- Multi-day campaign with daily resets
- Day counter: `/campaign` returns `day`, `totalDays`, `startedAt`, `nextResetAt`, `mintTarget`
- Pools reset daily: `/pools/today` shows GTD and FCFS remaining
- Mint target date: when WL holders can mint NFTs

### Referral System
- Referral tracking via X handle
- Referral link format: `https://x.com/USER/status/...`

## JS Bundle Analysis Commands

```bash
# 1. Download the main JS bundle
curl -sL "https://www.beppo.space/assets/index-*.js" > /tmp/beppo.js

# 2. Extract base URL variables
grep -oP '(\w+)\s*=\s*"https?://[^\"]+"' /tmp/beppo.js | grep -i 'beppo\|api\|render'

# 3. Extract all Xe() (fetch wrapper) calls with paths
grep -oP 'Xe\(\s*"(/[^"]*)"' /tmp/beppo.js | sort -u

# 4. Find HTTP method assignments
grep -oP 'Xe\("\([^"]*"\)\s*,\s*\{[^}]*method[^}]*:\s*"(\w+)"' /tmp/beppo.js

# 5. Extract localStorage keys used for auth
grep -oP 'localStorage\.(getItem|setItem|removeItem)\("\([^"]*\)"' /tmp/beppo.js | sort -u

# 6. Find admin-related patterns
grep -oP '(admin|ADMIN|admin-token|beppo_admin_token)[^;]{0,100}' /tmp/beppo.js | head -20
```

## Live Data Snapshot
```json
// /campaign
{"day":2,"totalDays":2,"startedAt":"2026-08-01T12:53:25.149Z","poolDate":"2026-08-02","nextResetAt":"2026-08-03T12:00:00.000Z","mintTarget":"2026-08-08T12:53:25.176Z"}

// /pools/today
{"poolDate":"2026-08-02","gtd":{"total":125,"remaining":9},"fcfs":{"total":250,"remaining":34},"nextResetAt":"2026-08-03T12:00:00.000Z"}

// /leaderboard (top 5)
[
  {"rank":1,"handle":"Thierno73166220","points":13175},
  {"rank":2,"handle":"amerliay5","points":12925},
  {"rank":3,"handle":"fjbrion","points":12750},
  {"rank":4,"handle":"Davidjohn286736","points":12525},
  {"rank":5,"handle":"mrpump6969","points":12500}
]
```

## Recon Notes
- Render.com hosting: API on `onrender.com` subdomain (free tier may sleep)
- Error format: Express.js default `"Cannot GET /path"` for undefined routes
- Admin panel has task filter UI: pool type (wl/nft), outcome filter (gtd/fcfs/points_back/dud)
- User data includes: handle, pfpUrl, points, wallet address, referral stats
- Raid tasks involve: X follows, retweets, quote tweets, replies, content creation
- Wallet change requires request submission + admin approval
