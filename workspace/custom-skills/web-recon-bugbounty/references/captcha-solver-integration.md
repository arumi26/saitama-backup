# Captcha Solver API Integration

Automated captcha solving via external API services (CapSolver-compatible like `sctg.xyz`). Use when the only gate between you and admin access is a 3-4 digit numeric captcha.

## HARD BOUNDARY — where a solver is allowed, and where it is NOT  ⛔

A solver is a tool for **reaching the target's own authorized surface** (admin panel, member area). It is **NOT** a tool for defeating **anti-bot / anti-abuse controls on account creation or login** of a service you don't own.

| Use case | Allowed? |
|---|---|
| App-level captcha on an in-scope target's admin/member login you are authorized to test | ✅ yes |
| Numeric/audio captcha gating access to the target's own backend surface | ✅ yes |
| **hCaptcha / reCAPTCHA / Turnstile on a service's public signup / registration / trial-account creation** | ❌ **NO** |
| Captcha on a login to a service where you don't own the account | ❌ NO |
| Solving to mass-create accounts, farm API keys, or bypass rate/abuse limits | ❌ NO |

**Why:** bypassing the anti-bot control a service puts on *identity creation* is **anti-bot evasion, not security research**. This is the user's explicit standing policy (see the `testnet-quest-bots` skill): *"NEVER use a CAPTCHA-solver service to get past Google/login CAPTCHA. That is anti-bot evasion on an account login, not research."* **Decline even when the user asks for it** — including when the target IS an authorized bounty program (an in-scope program authorizes testing, it does not authorize defeating its signup anti-abuse). If the user pasted a key, tell them to rotate it (now exposed in chat).

**Correct path when a needed account is captcha-walled** (e.g. you need a trial account to reach a server-side gate static analysis can't settle):
1. **The user creates the account themselves**, natively (real device, solves captcha + SMS/phone verification as a human). Clean, fast, zero evasion — and most program policies explicitly permit a self-owned trial account.
2. They hand you the credentials or a session token → you log in and run the authorized test.
3. If neither is possible and the finding is only reachable behind the wall, **downgrade to informational and move on** — do not solve or farm your way in.

> This reference previously encouraged solving login/register captchas, which conflicted with `testnet-quest-bots`. This boundary resolves it: solver for the target's *own* authorized surface, never for third-party account creation.

## When To Use

- Target has a captcha on the target's **own** authenticated surface you are authorized to test (admin panel, member area) — NOT on a third-party service's public signup/login
- OCR (Tesseract) accuracy is too low (< 70% on small images)
- You need human-level accuracy for a single-shot login **to an account you own**
- The captcha is server-side validated (not just client JS check)

## Workflow

### 1. Get Fresh Session + Captcha + ViewState (all in one)

```python
import subprocess, re, base64, json, time, urllib.parse

desktop = "TARGET"
api_key = "YOUR_API_KEY"
api_url = "https://api.sctg.xyz"  # or capsolver, etc.

# Get page with captcha
out = subprocess.run(['curl', '-sk', '-c', '/tmp/session.txt', '--max-time', '10',
    f'https://{desktop}/'], capture_output=True, text=True).stdout

# Extract ViewState AND captcha URL from same response
vs = re.search(r'name="__VIEWSTATE"[^>]*value="([^"]*)"', out, re.I)
cap_url = re.search(r'(/captchaimg\?[^"\']+)', out)

# Download captcha with SAME cookie jar
subprocess.run(['curl', '-sk', '-b', '/tmp/session.txt', '--max-time', '10',
    f'https://{desktop}{cap_url.group(1)}', '-o', '/tmp/captcha.png'])
```

### 2. Solve Captcha

```python
with open('/tmp/captcha.png', 'rb') as f:
    cap_b64 = base64.b64encode(f.read()).decode()

payload = json.dumps({
    "clientKey": api_key,
    "task": {
        "type": "ImageToTextTask",
        "body": cap_b64,
        "case": False,       # case-sensitive = false
        "numeric": 0,         # 0 = alphanumeric, 1 = digits only
        "minLength": 3,
        "maxLength": 3        # adjust for 3 or 4 digit captchas
    }
})

# Create task
resp = subprocess.run(['curl', '-s', '--max-time', '30',
    '-H', 'Content-Type: application/json', '-d', payload,
    f'{api_url}/createTask'], capture_output=True, text=True).stdout

data = json.loads(resp)
task_id = data.get('taskId')

# Poll for result
for i in range(10):
    time.sleep(2)
    rp = json.dumps({"clientKey": api_key, "taskId": task_id})
    resp2 = subprocess.run(['curl', '-s', '--max-time', '15',
        '-H', 'Content-Type: application/json', '-d', rp,
        f'{api_url}/getTaskResult'], capture_output=True, text=True).stdout
    
    rd = json.loads(resp2)
    if rd.get('status') == 'ready':
        solution = rd.get('solution', {}).get('text', '').strip()
        print(f"Solved: {solution}")
        break
```

### 3. Login with Solution

```python
vs_val = urllib.parse.quote(vs.group(1))
vsg_val = urllib.parse.quote(vsg.group(1)) if vsg else ''
ev_val = urllib.parse.quote(ev.group(1)) if ev else ''

data = (
    f'__VIEWSTATE={vs_val}'
    f'&__VIEWSTATEGENERATOR={vsg_val}'
    f'&__EVENTVALIDATION={ev_val}'
    f'&ctl00%24ctl00%24UCDesktopMainHeader1_1%24UCLoginForm1%24input_username={urllib.parse.quote(username)}'
    f'&ctl00%24ctl00%24UCDesktopMainHeader1_1%24UCLoginForm1%24input_password={urllib.parse.quote(password)}'
    f'&ctl00%24ctl00%24UCDesktopMainHeader1_1%24UCLoginForm1%24input_captcha={solution}'
    f'&ctl00%24ctl00%24UCDesktopMainHeader1_1%24UCLoginForm1%24btnLogin=LOGIN'
)

out = subprocess.run(['curl', '-sk', '-b', '/tmp/session.txt', '--max-time', '15',
    '-H', 'Content-Type: application/x-www-form-urlencoded',
    '-d', data, f'https://{desktop}/'], capture_output=True, text=True).stdout

if 'logout' in out.lower():
    print("LOGIN SUCCESS!")
```

## Pitfalls

### ViewState Single-Use

**CRITICAL:** You cannot reuse ViewState across captcha attempts. Each POST with a captcha consumes the ViewState. If the captcha is wrong, you MUST re-fetch the page to get a new ViewState AND a new captcha image — they're tied together in the session.

This means you get exactly ONE shot per captcha solve. No retrying with different captcha values on the same ViewState.

### Captcha Solver Accuracy

- 70×30px images: ~60-80% accuracy depending on noise
- 3-digit: usually 1 attempt needed
- 4-digit: may need 2-3 attempts
- If solver consistently returns wrong answers, try:
  - Removing `numeric` constraint
  - Removing `minLength`/`maxLength` constraint
  - Using `case: False` (no case sensitivity)
  - Enhancing image: resize 3-5x, increase contrast, sharpen

### Registration as Dummy

Some ASP.NET gambling sites have "registration" that returns "berhasil" / "sukses" but never actually creates an account. **Verify by:** registering the same username again — a real registration system should reject it as "already exists". If it succeeds again, registration is a dummy and the account doesn't exist.