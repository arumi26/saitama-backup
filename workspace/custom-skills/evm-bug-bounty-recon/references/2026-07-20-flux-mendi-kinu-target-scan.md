# Target Scan Session — 2026-07-20

## Targets Evaluated

| Protocol | Status | Reason |
|----------|--------|--------|
| **Kinu Finance** | DEAD | GitHub org 404, clone failed with `could not read Username for 'https://github.com'`. Background process `proc_e6f72167fe01` exit 0 but fatal error confirmed. |
| **Mendi Finance** | DEAD | Website shows "Mendi has been sunset." Last GitHub commit 2024-12-02. No bounty program found. |
| **Flux Finance** | CANDIDATE | $550K Immunefi bounty, public GitHub (`flux-finance/contracts`), cloned to `/tmp/flux-contracts`. Compound V2 fork + permissioned token extensions. |
| **Alchemix V2** | CANDIDATE | $300K max bounty, Base chain, public source (`alchemix-finance/v2-contracts`), cloned to `/tmp/alchemix-v2`. Initial scan complete: no low-level calls, no oracle refs, access control mapped. |
| **Zest Protocol V2** | LOW PRIORITY | $100K max bounty, but 4 audits already. Stacks/Clarity, not EVM. |
| **Origin Protocol** | LOW PRIORITY | $1M max bounty, but multiple audits, known issues documented. |

## Key Lessons

1. **Shallow clone ≠ complete repo.** Flux repo showed only 1 commit (`05bba79 Flux contracts:`) because of `--depth 1`. Always check `git log --all --oneline --decorate -n 20` to verify repo integrity before deep audit.

2. **Permissioned-token extensions on Compound V2 create NEW surfaces.** Flux adds `ISanctionsList` (Chainalysis), `IOndoPriceOracle` variants, and custom Comptroller logic. These are NOT covered by standard Compound audits. Focus audit on:
   - `contracts/external/chainalysis/ISanctionsList.sol` — sanctions check bypass
   - `contracts/lending/OndoPriceOracle*.sol` — oracle manipulation
   - `contracts/lending/compound/Comptroller.sol` — permissioning logic

3. **Dead protocol detection checklist (run BEFORE deep audit):**
   ```bash
   # Website alive?
   curl -sI https://<protocol>.finance | head -1
   
   # GitHub org exists?
   curl -s "https://api.github.com/orgs/<ORG>/repos?per_page=10" | python3 -c "import sys, json; data=json.load(sys.stdin, strict=False); print('ERROR' if isinstance(data,dict) and 'message' in data else 'OK')"
   
   # Last commit <12 months?
   curl -s "https://api.github.com/repos/<ORG>/<REPO>/commits?per_page=1" | python3 -c "import sys, json; data=json.load(sys.stdin, strict=False); print('OLD' if isinstance(data,list) and len(data)>0 and data[0]['commit']['committer']['date'][:4] < '2025' else 'OK')"
   ```

4. **Immunefi bounty ≠ exploitable.** Flux bounty page says "forked from CompoundV2" and "previously-discovered bugs are out of scope." Must find Flux-SPECIFIC bugs in permissioned extensions, not standard Compound bugs.

5. **Target scoring update:** Compound V2 forks with permissioned-token extensions = **Medium** priority (+1 modifier), not Low. Novel code in extensions = potential for new bug classes.