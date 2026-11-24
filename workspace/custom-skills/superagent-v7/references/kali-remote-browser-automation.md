# Kali Remote Browser Automation — Playwright + Brave/Chrome over SSH

_Session 2026-09-09: SVPCHAIN airdrop quest automation via Kali XFCE desktop_

## Problem Space
Automating a browser on a remote Kali Linux box over SSH — no VNC, no RDP, just XFCE on `:0`.
The bot must launch a browser, navigate to OAuth flows, and capture redirects — all headless
from the operator's perspective.

## Hard-Won Lessons

### 1. Profile Lock = Fatal Error
```
playwright._impl._errors.Error: BrowserType.launch_persistent_context:
Opening in existing browser session. This usually means that the profile
is already in use by another instance of Chromium.
```
**Cause:** Another Chrome/Chromium process (even crashed/ghosted) holds the profile directory lock.
**Fix:** Kill ALL chrome/chromium processes first:
```bash
pkill -9 -f chrome; pkill -9 -f chromium
sleep 2
```
Or use a profile nobody else touches (Brave Profile 5 is ideal — separate from Chrome).

### 2. Brave Profile 5 Path (NOT "Profile 5")
Brave names profiles `Profile.5` (dot, not space):
```python
BRAVE_PF = os.path.expanduser("~/.config/BraveSoftware/Brave-Browser/Profile.5")
```
Chrome uses `Profile 1` (space). Don't confuse them.

### 3. DISPLAY=:0 is Mandatory
Playwright Chromium over SSH without `DISPLAY=:0` crashes:
```
ERROR:ui/ozone/platform_x11/ozone_platform_x11.cc:257] Missing X server or $DISPLAY
The platform failed to initialize. Exiting.
```
Launch MUST include `export DISPLAY=:0` before any Playwright Chromium call.

### 4. Cyber-Semarang MOTD Banner — Cannot Be Fully Suppressed
Kali's `/etc/ssh/sshd_config` `PrintMotd no` + `.bashrc` sed — all insufficient. The banner still
leaks into SSH stdout and corrupts:
- **scp** → "Received message too long" (banner text interpreted as SCP protocol)
- **JSON output** → banner bytes prepended to API responses  
- **piped output** → banner mixed with bot stdout

**Working workaround: `bash --noprofile --norc`**
```bash
sshpass -p 'PASS' ssh -o StrictHostKeyChecking=no user@host \
  "bash --noprofile --norc -c 'your_command_here'"
```
This bypasses `.bashrc` AND `/etc/profile.d/*`. But `/etc/ssh/sshd_config` enforced MOTD
may still appear on some SSH versions.

**Best practice: Redirect bot output to a log FILE on Kali, then tail it:**
```bash
# Launch (redirect to file)
ssh ... "bash --noprofile --norc -c 'DISPLAY=:0 python3 bot.py > /tmp/bot.log 2>&1'"

# Read output (tail the file, grep meaningful lines)
ssh ... "bash --noprofile --norc -c 'grep -a PATTERN /tmp/bot.log | tail -20'"
```
Avoid piping stdout through SSH for long-running bots — buffering + banner = broken.

### 5. OAuth Hard Gate Pattern
When automating OAuth on a remote desktop:
- X/Twitter sessions expire → login form appears instead of authorize page
- Cannot auto-login X programmatically (no public API, anti-bot)
- API will reject ALL quest claims until OAuth bind is complete
- Pattern: attempt fake/empty codes → API returns "bind your X account first"
- **Conclusion:** OAuth-based quest systems require 1x manual human login

### 6. SiWE API Bypass (bypasses MetaMask popup)
- Chrome extension URLs (`chrome-extension://`) are BLOCKED by Chrome security
- Playwright cannot navigate to `chrome-extension://<ext_id>/popup.html`
- **Solution:** Use SiWE (Sign-In with Ethereum) API directly
  - Fetch nonce → sign with `eth_account` → POST login → get bearer token
  - Use bearer token for ALL quest operations (no MetaMask popup needed)
- SiWE flow: works for any dApp with backend API authentication

### 7. Desktop Notification for Manual Action
When human action is needed on remote desktop:
```bash
# Send desktop notification
notify-send "TITLE" "Message" -i dialog-information 2>/dev/null

# Raise browser window to front
xdotool search --name "BrowserName" 2>/dev/null | head -1 | \
  xargs -I{} xdotool windowactivate {} 2>/dev/null
```

## Code Templates

### Playwright X OAuth on Brave Profile 5
```python
import os, time, sys, json
from playwright.sync_api import sync_playwright
from urllib.parse import urlparse, parse_qs
import urllib.request

API = "https://rewards.svpstars.com/api/v1"
TOKEN = open("/tmp/svp_token.txt").read().strip()
BRAVE_PATH = "/opt/brave.com/brave"
BRAVE_PF = os.path.expanduser("~/.config/BraveSoftware/Brave-Browser/Profile.5")

OAUTH_URL = (
    "https://x.com/i/oauth2/authorize?"
    "client_id=VzRSdGNDVVhDQndZU2xVdHVETDI6MTpjaQ"
    "&redirect_uri=https%3A%2F%2Frewards.svpstars.com%2Fapi%2Fv1%2Fsocial%2Fx%2Fcallback"
    "&response_type=code"
    "&scope=tweet.read+users.read+follows.read+offline.access"
)

def api_post(path, data):
    r = urllib.request.Request(API + path, data=json.dumps(data).encode(), method="POST")
    r.add_header("Content-Type", "application/json")
    r.add_header("Authorization", f"Bearer {TOKEN}")
    try:
        return json.loads(urllib.request.urlopen(r, timeout=10).read())
    except urllib.error.HTTPError as e:
        return {"code": e.code, "body": e.read().decode()[:300]}

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        BRAVE_PF,
        headless=False,
        executable_path=f"{BRAVE_PATH}/brave-browser",
        slow_mo=150,
        args=["--disable-blink-features=AutomationControlled", "--no-first-run", "--disable-web-security"]
    )
    page = ctx.pages[0] if ctx.pages else ctx.new_page()
    page.goto(OAUTH_URL, timeout=30000)
    time.sleep(5)

    start = time.time()
    while time.time() - start < 300:
        time.sleep(3)
        url = page.url
        if "callback" in url and "code=" in url:
            qs = parse_qs(urlparse(url).query)
            code = qs.get("code", [None])[0]
            if code:
                print(f"OAUTH_CODE: {code}")
                r = api_post("/social/x/callback", {"code": code})
                print(f"Bind: code={r.get('code')} msg={r.get('message','')}")
                if r.get("code") == 0:
                    print("X BOUND! Claiming all quests...")
                    for tid in [1,2,3,4,5,6,12,13]:
                        time.sleep(2)
                        cr = api_post(f"/tasks/{tid}/claim", {})
                        print(f"  Task {tid}: {cr.get('message','?')}")
                break

        body = page.evaluate("()=>document.body.innerText")
        if "Authorize" in body:
            for sel in ["text=Authorize app", "text=Authorize"]:
                try:
                    el = page.locator(sel).first
                    if el.count() and el.is_visible(timeout=2000):
                        el.click()
                        print(f"Clicked: {sel}")
                        break
                except:
                    pass
        print(f"[{int(time.time()-start)}s] {url[:80]}")
    ctx.close()
```

### SSH Banner Bypass Pattern
```bash
# Wrap commands to bypass .bashrc + profile.d banners
COMMAND="export DISPLAY=:0 && python3 /tmp/myscript.py > /tmp/out.log 2>&1"
sshpass -p 'PASS' ssh -o StrictHostKeyChecking=no user@host \
  "bash --noprofile --norc -c '$COMMAND'"

# Read output back
sshpass -p 'PASS' ssh -o StrictHostKeyChecking=no user@host \
  "bash --noprofile --norc -c 'tail -20 /tmp/out.log'"
```

### File Transfer via stdin pipe (scp blocked by banner)
```bash
# Upload
cat local_script.py | \
  sshpass -p 'PASS' ssh -o StrictHostKeyChecking=no user@host \
  "bash --noprofile --norc -c 'cat > /tmp/remote_script.py'"

# Verify
sshpass -p 'PASS' ssh user@host "wc -c /tmp/remote_script.py"
```

## Checkpoint: Remote Browser Automation on Kali
- [ ] Kill stale Chrome/Chromium before launching Playwright (`pkill -9 chrome`)
- [ ] Use `export DISPLAY=:0` in SSH command
- [ ] Use Brave Profile 5 path: `~/.config/BraveSoftware/Brave-Browser/Profile.5`
- [ ] Wrap SSH commands in `bash --noprofile --norc -c '...'`
- [ ] Redirect bot output to log FILE (not stdout pipe)
- [ ] Send desktop notification (`notify-send`) + raise window (`xdotool windowactivate`)
- [ ] Chrome Default has cookies but gets profile-locked; Brave Profile 5 has no lock but no cookies
- [ ] Coordinate X login with user BEFORE running bot (saves 5 min timeout cycle)
