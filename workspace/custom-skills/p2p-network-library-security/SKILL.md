
# P2P Network Library Security Analysis

## Prerequisites
```bash
# Clone target repo
git clone --depth 1 <repo-url> /tmp/p2p-audit-target
find /tmp/p2p-audit-target -name "*.rs" | wc -l  # count source files
```

## GitHub Source Fetching (No-Clone Shortcut)
When cloning is too slow or fails (no space, network), fetch raw source via GitHub API:
1. **Check default branch**: `curl -s "https://api.github.com/repos/OWNER/REPO" | jq -r '.default_branch'`
2. **Monorepo trap**: many projects nest sub-modules in a parent repo (e.g., `n0-computer/noq` contains `noq-proto/`, `iroh/`, `iroh-relay/`). A separately-named repo may not exist.
3. **Discover paths**: `curl -sL "https://github.com/OWNER/REPO/tree/BRANCH/PATH" | grep -oP 'href="/OWNER/REPO/blob/[^"]*"' | head -30`
4. **Fetch raw file**: `curl -sL --max-time 10 "https://raw.githubusercontent.com/OWNER/REPO/BRANCH/path/to/file.rs"`
5. **Rate limit**: set `--max-time 10` on all GitHub curl calls to avoid hanging on rate-limited accounts.

## Analysis Framework (7 Layers)

### Layer 1: Cryptographic Identity
Map how endpoints authenticate and establish identity:
- **Key derivation**: Ed25519, X25519, secp256k1, etc.
- **Encoding**: z-base-32, base64url, hex — check for canonicalization issues
- **Key verification**: curve point validation, byte-level strictness
- **Key storage**: in-memory only, encrypted at rest, MPC/TSS
- **Key rotation**: is re-keying supported? Can an attacker force re-key?

**Security concerns:**
- Missing curve point validation → key confusion attacks
- Weak key derivation → predictable endpoint IDs
- No key rotation → stolen key = permanent compromise
- Non-canonical encoding → identity mismatch

### Layer 2: TLS / Transport Security
Map TLS configuration and handshake protocols:
- **CA roots**: Embedded WebPKI (rustls) vs system vs custom
- **Certificate types**: TLS 1.3 full, TLS-PSK (RFC 5705 export), self-signed
- **ALPN protocols**: custom protocol names, version negotiation
- **Cipher suites**: forward secrecy (ECDHE), AEAD only?
- **Insecure modes**: test-only bypasses, `danger_accept_invalid_certs`

**Security concerns:**
- TLS-PSK export without channel binding → MITM on relay
- Insecure modes reachable in non-test builds → critical
- Missing certificate pinning on relay endpoints → relay impersonation
- ALPN downgrade → protocol confusion

### Layer 3: NAT Traversal & Hole Punching
Map how endpoints connect through NATs/firewalls:
- **Protocols supported**: UPnP, PCP, NAT-PMP, STUN, ICE, QNT
- **Port mapper config**: Enabled, Disabled, or auto
- **Hole punch interval**: How often NAT mappings are refreshed
- **Candidate announcement**: How local addresses are shared
- **Fallback paths**: When hole punching fails → relay

**Security concerns:**
- UPnP without source IP validation → arbitrary port mapping
- NAT mapping exhaustion via rapid hole punch attempts (DoS)
- STUN response spoofing → redirect to attacker's IP
- No rate limiting on NAT refresh → bandwidth waste, battery drain

### Layer 4: Transport Selection & Path Multiplexing
Map how the library chooses which path to use:
- **Path selector algorithm**: RTT-based, biased, custom
- **Tiering**: Primary (IP) vs Backup (Relay) — cross-tier switching
- **Stickiness**: Switching thresholds to prevent flapping (e.g., 5ms)
- **IPv6 bias**: Default preference for IPv6, configurable?
- **Multipath**: How many concurrent paths, load balancing?
- **Upgrade path**: Can direct connection be upgraded from relay?

**Security concerns:**
- No transport type enforcement → attacker forces relay for MITM
- RTT-based selection vulnerable to RTT manipulation (packet injection)
- Cross-tier switching without validation → path hijack
- Relay fallback without re-authentication → downgrade attack
- **Multipath path count**: if minimum is enforced (e.g., clamped to 14), resource exhaustion via connection flooding

### Layer 5: Connection State Machine
Map connection lifecycle and state transitions:
- **States**: Connecting → Handshake → Established → Closing
- **Type-state pattern**: Compile-time state tracking (e.g., `Connection<HandshakeCompleted>`)
- **0-RTT handling**: replay vulnerability, session resumption, server-side state
- **Stream lifecycle**: uni/bi-directional, priority, backpressure
- **Idle timeout**: per-path and global, configurable?
- **Connection closure**: graceful vs abrupt, pending data handling

**Security concerns:**
- **0-RTT replay**: sent data accepted before handshake verification
- State transition race conditions (TOCTOU)
- Missing stream backpressure → memory exhaustion
- Idle timeout too long → resource leak, zombie connections
- No stream multiplexing limits → DoS via open streams

### Layer 6: Relay / Fallback Transport
Map how relay servers work:
- **Handshake**: challenge-response signing, TLS-PSK, token-based
- **Authentication**: Ed25519 signature over endpoint ID + timestamp
- **Rate limiting**: per-connection, per-bandwidth, per-message
- **Message forwarding**: encrypted? replay protection? ordering?
- **Home relay selection**: automatic, manual, or sticky

**Security concerns:**
- Missing replay protection on relay messages → replay attacks
- No message ordering guarantee → protocol confusion
- Relay server impersonation (not verified against trusted list)
- Bandwidth exhaustion via flood of small relay messages

### Layer 7: Address Resolution & Discovery
Map how endpoints find each other:
- **PKARR**: signed DNS-like records on Mainline DHT, signed by endpoint's own key
- **DNS**: TXT records under `_iroh.<z32-id>.<domain>`, staggered timeout queries
- **Bootstrap nodes**: hardcoded, configurable, or dynamic?
- **Publishing**: exponential backoff on failure, periodic refresh
- **Staging vs Production**: separate domains for testing

**Security concerns:**
- PKARR record forgery if DHT can be eclipsed
- DNS record spoofing via cache poisoning
- No signature verification on resolved addresses → address takeover
- Bootstrap node compromise → network partition

## Reference Case Studies
- `references/iroh-case-study-2026-08-03.md` — Full iroh (n0-computer/iroh) analysis: all 7 layers, transport multiplexing fairness, BiasedRttPathSelector algorithm, 0-RTT replay, UPnP/NAT-PMP/PCP, PKARR+DNS resolution, security assessment summary
- `references/iroh-noq-security-findings-2026-08-03.md` — Session-specific security findings from deep code review of `n0_nat_traversal.rs`, `token.rs`, `crypto.rs`, `frame.rs`, `connection.rs`: 12 findings across NAT traversal, token system, crypto layer, frame protocol

## Transport Multiplexing Fairness Check

When analyzing transport polling loops, check for starvation:
- **Forward/reverse alternation**: every 2nd poll reverses order to prevent starvation
- **Early return on data**: first transport with data returns immediately
- **Error counting**: all transports failing consecutively triggers shutdown after N attempts
- **Race pattern**: if polling is always forward-only, later transports (relay, custom) may be starved

## Path Selection Vulnerability Checklist

```
□ Is relay always backup, or can it win over IP paths?
  → If relay CAN win, attacker can force traffic through controlled relay
□ Is switching threshold configurable?
  → If hardcoded low (e.g., 1ms), path flapping = DoS
□ Is IPv6 bias hardcoded or configurable?
  → If hardcoded, IPv4 users penalized regardless of actual latency
□ Can path stats be manipulated?
  → If RTT is computed from receive timestamps, attackers can inject packets
    to make a path appear faster than it actually is
□ Multipath count clamped to minimum?
  → Forces N paths even when only 1 exists — potential resource waste
```

## 0-RTT Security Analysis

For any QUIC/TLS implementation with 0-RTT support:
1. **Data acceptance window**: when is 0-RTT data actually processed (before or after handshake)?
2. **Replay detection**: does the server track session tickets and reject duplicates?
3. **Idempotency**: are 0-RTT streams restricted to idempotent operations?
4. **Server-side state**: can an attacker replay 0-RTT data to trigger non-idempotent actions?
5. **Session ticket management**: are tickets rotated? reused? shared across servers?

**Finding template for 0-RTT vulnerability:**
- Severity: HIGH (replay-based)
- Condition: server accepts 0-RTT data before verifying handshake
- Impact: replay of state-changing operations (transfer, approve, claim)
- Mitigation: server-side ticket deduplication, 0-RTT restricted to GET/idempotent

## Relay Authentication Bypass Patterns

1. **Challenge-response replay**: if timestamp validation is missing or too lenient
2. **TLS-PSK key confusion**: if the exported key is used for both encryption and auth
3. **Endpoint ID validation**: after relay forwards the connection, does the direct peer verify the ID?
4. **Certificate pinning on relay**: does the client verify it's connecting to the trusted relay list?

## NAT Traversal Attack Surface

| Vector | Severity | Description |
|--------|----------|-------------|
| UPnP source validation | HIGH | If UPnP doesn't validate source IP of control requests, attacker can open arbitrary ports |
| STUN response spoofing | MEDIUM | Fake STUN responses redirect hole punch to attacker IP |
| NAT mapping exhaustion | MEDIUM | Rapid hole punch attempts drain NAT table entries |
| PCP scope validation | HIGH | PCP requests without source address validation |
| ICE candidate fabrication | LOW | Fake candidates waste bandwidth on useless connection attempts |

## Path State Actor Lifecycle Analysis

For actor-based path management systems:
1. **Idle timeout**: how long before actor stops? (e.g., 60s)
2. **Restart behavior**: when actor restarts, does it preserve path state?
3. **Message ordering**: are path events processed in order? Lag detection?
4. **Connection close handling**: cleanup of stale state, path removal
5. **Network change detection**: does major network change trigger full hole punch?

**Finding template for actor lifecycle bug:**
- Severity: MEDIUM-HIGH
- Condition: actor stops during active connection, restart loses path state
- Impact: connection drops, requires full reconnect + hole punch
- Mitigation: persist state to disk, faster actor restart

## Deliverable Format

### Architecture Summary
- Protocol: name, version, language, deps
- Core stack: crypto, transport, NAT, relay, discovery
- Key design decisions: embedded vs system CAs, relay as backup, type-state connections

### Security Findings
For each finding:
1. **Vulnerability class**: crypto, transport, NAT, protocol, DoS, logic
2. **Severity**: CRITICAL/HIGH/MEDIUM/LOW with justification
3. **Code location**: file:line or module
4. **Attack scenario**: step-by-step exploitation
5. **Impact**: what an attacker gains
6. **Fix recommendation**: concrete code change

### PoC Potential
- Can this be proven in simulation? (Foundry/anvil/fork)
- Is an on-chain/on-network PoC feasible?
- What data is needed (RPC, relay access, NAT config)?
