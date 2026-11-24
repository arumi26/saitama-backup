# Doppler Finance — Audit Notes (2026-07-18)

## Repo
- `https://github.com/whetstoneresearch/doppler`
- Local clone: `/tmp/doppler`

## Active Bug Bounty
- Platforms: HackerOne + Cantina
- Program status: active

## Audit Status
- Core contracts reviewed: `Airlock.sol`, `TopUpDistributor.sol`, `Governance.sol`, `DopplerERC20V1.sol`, `DopplerDN404.sol`, `DopplerHookInitializer.sol`, `DopplerHookMigrator.sol`, `RehypeDopplerHookInitializer.sol`, `FeesManager.sol`, `UniswapV2MigratorSplit.sol`
- Confirmed critical fund-loss bug: none yet
- Retired false positive: `TopUpDistributor.setPullUp()` front-run claim — verified `msg.sender != AIRLOCK.owner()` revert is hard, not bypassable via tx ordering
- Access controls appear solid: `onlyAirlock`, `onlyOwner`, owner checks enforced
- Fee/hook paths are permissioned

## Key Attack Surfaces Still Worth Reviewing
- `src/base/` and `src/lockers/` for edge-case fund-loss
- Migrator authorization flows between `Airlock` and `TopUpDistributor`
- Hook flag updates in `setDopplerHookState()` — owner-only, but check for missed validation in child contracts
- DN404 freeze/unfreeze logic for accounting edge cases

## Lessons
- Doppler uses non-standard JWT-like tokens with binary payloads; standard JWT parsing may fail
- `TopUpDistributor.sol` owner-gated functions are not vulnerable to simple front-running because of hard `msg.sender` checks
