/**
 * SSRF guard probe — audit whether an `assertPublicUrl`-style guard is bypassable.
 *
 * Usage:
 *   node --experimental-strip-types scripts/ssrf-guard-probe.ts [guardModule] [exportName]
 *
 * Examples:
 *   node --experimental-strip-types scripts/ssrf-guard-probe.ts
 *       -> prints only the parser/resolver normalization facts (no target needed)
 *   node --experimental-strip-types scripts/ssrf-guard-probe.ts ./skills/web-scraping/src/ssrf.ts
 *       -> also fires the full encoding battery at the guard's default export name
 *   node --experimental-strip-types scripts/ssrf-guard-probe.ts ./src/ssrf.ts assertPublicUrl
 *
 * The guard module must export an async function that throws on a blocked URL and
 * resolves on an allowed one (the conventional shape). If dynamic import of a .ts
 * file fails on your Node build, copy this probe next to the guard and import it
 * with a relative specifier instead.
 *
 * READING THE OUTPUT — the point is not "did it print blocked". It is:
 *   1. Is any row ALLOWED that should be private?  -> real bypass, report it.
 *   2. WHICH branch blocked the IPv6 rows — "private address" or "does not resolve"?
 *      A guard that fails OPEN on unresolvable hosts is broken even if every row
 *      below says "blocked", so check the message text, not just the verdict.
 *   3. Does the guard re-parse via `new URL()` before checking? Compare the
 *      normalization section against what the guard reports as the host.
 */

import { lookup } from 'node:dns/promises';

// ── The battery ─────────────────────────────────
// Ordered: plain literals, alt IPv4 encodings, wildcard DNS, IPv6 (incl. mapped),
// NAT64, and a deliberately non-resolving control (must be DENIED, not allowed).
const BATTERY: Array<[string, string]> = [
  ['http://127.0.0.1/', 'plain loopback'],
  ['http://127.1/', 'short IPv4'],
  ['http://2130706433/', 'decimal IPv4'],
  ['http://0177.0.0.1/', 'octal IPv4'],
  ['http://0x7f000001/', 'hex IPv4'],
  ['http://localhost/', 'localhost name'],
  ['http://169.254.169.254/', 'cloud metadata'],
  ['http://127.0.0.1.nip.io/', 'wildcard DNS -> private'],
  ['http://[::1]/', 'IPv6 loopback'],
  ['http://[::7f00:1]/', 'IPv6 compressed mapped loopback'],
  ['http://[::ffff:127.0.0.1]/', 'IPv6 mapped dotted-quad'],
  ['http://[0:0:0:0:0:ffff:7f00:1]/', 'IPv6 EXPANDED mapped'],
  ['http://[0:0:0:0:0:0:0:1]/', 'IPv6 EXPANDED loopback'],
  ['http://[64:ff9b::7f00:1]/', 'NAT64 well-known prefix'],
  ['http://spoofed.example.com/', 'non-resolving control (must DENY)'],
];

async function normalizationFacts(): Promise<void> {
  console.log('=== Parser / resolver normalization (no target needed) ===\n');

  console.log('new URL(...).hostname  — the WHATWG parser canonicalizes BEFORE a guard sees it:');
  for (const [u, label] of BATTERY) {
    try {
      const host = new URL(u).hostname;
      console.log(`  ${label.padEnd(34)} ${u.padEnd(34)} -> ${host}`);
    } catch {
      console.log(`  ${label.padEnd(34)} ${u.padEnd(34)} -> (unparseable)`);
    }
  }

  console.log('\ndns.lookup(...)  — Node resolves exotic IPv4 literals itself:');
  for (const h of ['2130706433', '0177.0.0.1', '0x7f000001', '127.1', '127.0.0.1']) {
    try {
      const r = await lookup(h, { all: true });
      console.log(`  ${h.padEnd(16)} -> ${JSON.stringify(r)}`);
    } catch (e) {
      console.log(`  ${h.padEnd(16)} -> ERR ${(e as Error).message}`);
    }
  }

  console.log('\nTakeaway: expanded-form and exotic-literal "bypasses" usually collapse to a');
  console.log('form the guard already blocks. Prove reachability here before writing it up.\n');
}

async function runBattery(modPath: string, exportName: string): Promise<void> {
  const mod: Record<string, unknown> = await import(modPath);
  const guard = mod[exportName] as ((u: string) => Promise<unknown>) | undefined;
  if (typeof guard !== 'function') {
    console.error(`!! ${modPath} has no exported function '${exportName}'`);
    console.error(`   exports: ${Object.keys(mod).join(', ')}`);
    process.exitCode = 2;
    return;
  }

  console.log(`=== Battery against ${modPath}#${exportName} ===\n`);
  let bypasses = 0;
  for (const [u, label] of BATTERY) {
    let verdict: string;
    try {
      await guard(u);
      verdict = 'ALLOWED  <== BYPASS';
      bypasses++;
    } catch (e) {
      verdict = 'blocked  ' + (e as Error).message.slice(0, 70);
    }
    console.log(`${label.padEnd(34)} ${u.padEnd(34)} ${verdict}`);
  }

  console.log(`\n${bypasses === 0 ? 'No bypasses.' : `${bypasses} row(s) ALLOWED — triage each.`}`);
  console.log('If the IPv6 rows say "does not resolve", confirm that branch DENIES rather');
  console.log('than allows — a fail-open resolver check is the real bug in this class.');
}

async function main(): Promise<void> {
  const [, , modPath, exportName = 'assertPublicUrl'] = process.argv;
  await normalizationFacts();
  if (modPath) await runBattery(modPath, exportName);
  else console.log('(pass a guard module path to also fire the battery)');
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
