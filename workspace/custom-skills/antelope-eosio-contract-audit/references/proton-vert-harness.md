# @proton/vert harness — template + SLASH-2026-02 case study

## 1. Test file template (drop into `contracts/<name>/tests/`)

Mirror the project's own setup verbatim — copy the deploy/auth block from an existing
`tests/*.test.ts`. The shape below is the XPR Network `agentvalid` pattern.

```ts
import { expect } from 'chai';
import { Blockchain, protonAssert, expectToThrow, mintTokens, nameToBigInt } from '@proton/vert';
import { TimePointSec } from '@greymass/eosio';

const blockchain = new Blockchain();
const eosioToken = blockchain.createContract('eosio.token', 'contracts/eosio.token/eosio.token');
// deploy the target(s) + any dependency contract they import (deploy dep first):
const agentcore  = blockchain.createContract('agentcore',  'contracts/agentcore/assembly/target/agentcore.contract');
const agentvalid = blockchain.createContract('agentvalid', 'contracts/agentvalid/assembly/target/agentvalid.contract');

const owner = 'owner', validator1 = 'validator1', vtwo = 'vtwo', challenger1 = 'challenger1';

const bootstrap = async () => {
  blockchain.resetTables();
  // Chain time starts at 0 and PERSISTS across tests in a run. Any action gated on a
  // nonzero timestamp (e.g. `check(funded_at > 0)`) fails spuriously without this nudge.
  blockchain.addTime(TimePointSec.from(1000000));
  await mintTokens(eosioToken, 'XPR', 4, 1000000000, 100000, [owner, validator1, vtwo, challenger1]);
  await agentcore.actions.init(['owner', 0, 100000, '', 'agentvalid', '']).send('agentcore@active');
  await agentvalid.actions.init(['owner', 'agentcore', 10000]).send('agentvalid@active');
};

describe('agentvalid: <finding>', () => {
  beforeEach(bootstrap);

  it('...', async () => {
    await agentvalid.actions.regval(['vtwo', ...]).send('vtwo@active');
    await eosioToken.actions.transfer(['vtwo', 'agentvalid', '100000 XPR', 'stake']).send('vtwo@active');
    // ...
  });
});
```

Run:
```bash
npx ts-mocha -p tests/tsconfig.json tests/<file>.test.ts --timeout 60000
npx ts-mocha -p tests/tsconfig.json tests/*.test.ts     --timeout 60000   # full suite / regression
```

## 2. vert pitfalls (both cost real time)

| Symptom | Cause | Fix |
|---|---|---|
| Timestamp-gated action rejects for no reason | chain time is 0 and persists across tests | `blockchain.addTime(TimePointSec.from(1000000))` in bootstrap |
| Sends after an `expectToThrow` break | `expectToThrow` corrupts the tx context | make the throwing call the LAST step, or isolate with `resetTables()`+redeploy |
| `Name` table key compare fails | keys are `u64` | `nameToBigInt('acct')` |

## 3. Case study — SLASH-2026-02 (reactive-guard ordering bypass)

Target: XPR Network `agentvalid` @ `1418dade3d5fd71a0fca7c601a9fa0cd68bb01ff`.

Three cases, all green (`3 passing`), full suite `52 passing` (49 existing + 3 new, no regression):

1. `validate()` then `unstake()` → **blocked** (the 2026-01 fix works for this ordering).
2. Baseline (no pre-unstake) + upheld challenge → slashes `10% of 100000 = 10000`.
3. **Bypass** `unstake(90000)` → `validate()` → upheld challenge → slashes `10% of 10000 = 1000`,
   then `withdraw()` releases the queued 90000 after `unstake_delay`.

Core of case 3:
```ts
await registerAndStake('vtwo');                                    // stake = 100000
await agentvalid.actions.unstake(['vtwo', 90000]).send('vtwo@active');   // no valactivity -> lock silent
expect(Number(getValidator('vtwo').stake)).to.equal(MIN_STAKE);    // 10000
await agentvalid.actions.validate(['vtwo', 'alice', 'jobhash', 1, 95, 'ipfs://e']).send('vtwo@active');
await challengeAndResolve();                                       // upheld
expect(Number(getValidator('vtwo').stake)).to.equal(MIN_STAKE - 1000);   // 9000 vs 90000 baseline
blockchain.addTime(TimePointSec.from(UNSTAKE_DELAY + 10));
await agentvalid.actions.withdraw(['vtwo', 0]).send('vtwo@active');      // 90000 released
```

Root cause (agentvalid HEAD, `unstake`): the valactivity time-lock only fires when a row
already exists; `validate()` never checks for a pending unstake; `withdraw()` and `resolve()`
never read valactivity. Recommend gating `validate()` on "no pending unstake".

Severity calibration: the *original* same-class finding (XPRA-VALID-SLASH-2026-01) paid
15,000 XPR (HIGH). Report the bypass as HIGH with an honest "incomplete fix of a paid finding"
framing — do not inflate.

## 4. Build-order gotcha

`agentvalid` imports `agentcore`; its test deploy needs `agentcore`'s
`assembly/target/agentcore.contract.wasm` to exist first. Build the dependency, then the target:

```bash
cd contracts/agentcore && npm install && npm run build
cd ../agentvalid        && npm install && npm run build
```
