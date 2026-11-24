# Non-EVM Custom L1 Audit — Redbelly Network Reference (Sept 2026)

## Target Profile
- **Name:** Redbelly Network
- **Chain ID:** 153 (testnet)
- **Client:** Go-based custom EVM implementation (go1.25.12 from Server header)
- **Bug Bounty Platform:** Hashlock (not Immunefi)
- **Contact:** info@redbelly.network
- **Scope:** L1 native features (identity, credentials, consensus) — NOT DeFi

## RPC Capabilities
| Method | Status | Notes |
|--------|--------|-------|
| eth_call | ✅ | Read-only contract calls |
| eth_getCode | ✅ | Bytecode retrieval |
| eth_blockNumber | ✅ | Current block |
| txpool_content | ✅ | Pending TX leak (empty on testnet) |
| txpool_inspect | ✅ | TX monitoring |
| eth_accounts | ✅ | Returns empty (no unlocked keys) |
| eth_syncing | ✅ | False = fully synced |
| net_version | ❌ | Restricted |
| debug_traceTransaction/Call | ❌ | Not available |
| personal_listAccounts | ❌ | Good — node accounts protected |

## Live Contract Under Audit
| Property | Value |
|----------|-------|
| Address | `0x5c414F9243588750E4BB1Ec181270ad42A0b791F` |
| Bytecode | 5542 bytes |
| Bal | 0 native tokens |
| credentialType selector | `0x2e17b05b` → "OptimaV1Credential" |
| verificationStatus selector | `0xadafb3d4` → bool mapping |
| Confirmed verified user | `0xff96eb8458e7764FFB5995adf6F7138DE66F52d3` |
| Issuer DID | `did:key:zAeVG1300Ft4byWDW3NbuxooIjQvA8P16GCiL0Gj9Hg=` |
| Valid Until | 2028-04-01 (IGNORED by contract) |

## Bytecode Metrics
- delegatecall (0xF4): 21 — библиотеки (JsonFormatter, Base58, TimeParserUtils, StringToAddress)
- CALL (0xF1): 41 — external call surface
- STATICCALL (0xFA): 3 — read-only external calls
- JUMPI (0x57): 112 — conditional branches
- REVERT (0xFD): 58 — error handling
- SELFDESTRUCT (0xFF): 121 — likely dead code from proxy scaffolding
- CALLVALUE (0x34): 10 — payable checks
- CALLER (0x33): 19 — auth checks
- ORIGIN (0x32): 10 — anti-phishing checks

## Confirmed Findings (Redbelly VC Verifier)
1. **CRITICAL (CVSS 9.8):** No credential expiry enforcement — `validUntil` in VC JSON completely ignored
2. **HIGH:** No verifier-binding — proof replayable across all contracts with same credentialType
3. **MEDIUM:** Caller identity mismatch — `msg.sender` stored instead of `credentialSubject.publicAddress`
4. **MEDIUM:** Ed25519 edge cases — private npm package, unaudited library

## Key Learnings
- private npm packages on GitHub Packages require auth token — cannot download without org membership
- Go client version leaks in HTTP Server headers useful for fingerprinting
- PUSH4 opcode (0x63) in bytecode = function selector — brute-force fuzzing reveals function names
- Delegatecall opcode count = number of library-linked contracts
- Selfdestruct count = likely safe (compiler artifacts from proxy scaffolding) BUT verify when source available

## Contact / Submission
- Hashlock: https://hashlock.com/bug-bounty/redbellynetwork
- Email: info@redbelly.network
- X/Twitter: @RedbellyNetwork
