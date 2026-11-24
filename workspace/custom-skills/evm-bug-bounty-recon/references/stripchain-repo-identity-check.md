# StripChain Repository Identity Check — July 2026

## Signal
User requested `https://home.stripchain.xyz` as a new bounty target. Recon found a GitHub org `StripChain` with 2 repos: `v3-core` and `v3-periphery`.

## Finding
Both repos are **Uniswap V3 forks**, not StripChain protocol code:
- README/bug-bounty files contain Uniswap V3 text
- No StripChain-specific contracts, modules, or bounty scope
- Whitepaper describes StripVM/StripIntent, but no matching implementation in GitHub

## Lesson
GitHub org discovery alone is insufficient. Always verify repo identity before auditing:
1. Read `README.md` and `bug-bounty.md` for project-specific language
2. Check for protocol-specific contract names vs generic templates
3. Confirm disclosed bounty scope or security contact exists
4. If repo is a famous-template fork without target-specific code, **do not audit**

## Outcome
StripChain blocked as bounty target until actual disclosed contracts/repo/addresses are provided.
