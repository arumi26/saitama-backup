# Iroh (n0-computer/iroh) — Source Code Analysis Case Study
**Date**: 2026-08-03
**Target**: iroh-base, iroh-relay, noq, noq-udp
**Source**: GitHub raw files via curl (no clone — disk space constrained)

## Architecture Overview

### Core Stack
- **Language**: Rust (2024 edition for `noq`)
- **P2P transport**: QUIC via `noq` (custom implementation, not libquic)
- **Crypto**: Ed25519 (`ed25519-dalek`), X25519, rustls (TLS 1.3)
- **Crypto providers**: `ring` (preferred) or `aws-lc-rs` (optional feature)
- **NAT traversal**: UPnP, PCP, NAT-PMP via `portmapper` crate; STUN via `noq_proto::n0_nat_traversal`
- **Relay**: WebSocket-based relay server with challenge-response Ed25519 authentication
- **Address resolution**: PKARR (signed records on Mainline DHT) + DNS (TXT records)
- **Path selection**: `BiasedRttPathSelector` with tier-based switching

### Key Design Decisions
1. **Embedded WebPKI**: Default CA roots from Mozilla (embedded in binary), not system CAs
2. **Relay as backup**: Relay paths NEVER override IP paths regardless of RTT
3. **Type-state connections**: `Connection<HandshakeCompleted>`, `Connection<OutgoingZeroRtt>` tracked at compile time
4. **Actor-based path management**: Per-remote-endpoint `RemoteStateActor` handles all connections
5. **Presets pattern**: `N0` preset bundles PkarrPublisher + PkarrResolver + DnsAddressLookup + crypto provider

## Layer-by-Layer Findings

### L1: Cryptographic Identity
- **Key type**: Ed25519 public key, 32 bytes, z-base-32 encoded
- **Endpoint ID**: Derived from Ed25519 pubkey → z-base-32 string
- **Curve verification**: Strict byte-level validation of public key points
- **Signing**: Ed25519 signature over endpoint ID for relay authentication
- **No key rotation**: Endpoint ID is immutable (derived from pubkey)

**Finding**: No key rotation mechanism. If an endpoint's private key is compromised, the attacker has permanent identity.

### L2: TLS Configuration
- **CaTlsConfig** modes:
  1. `EmbeddedWebPki` (default): Mozilla CA roots baked into binary
  2. `System`: OS system CA store
  3. `Custom`: User-provided CA file
  4. `Insecure`: Accepts ANY certificate (test-only, gated behind `with-insecure-tls` feature)
- **ALPN**: Custom protocol name for iroh QUIC
- **Cipher suites**: TLS 1.3 only, ECDHE + AEAD

**Finding**: `Insecure` mode exists but is properly gated behind feature flag + test-only. No test-only TLS bypass in production builds.

### L3: Relay Handshake
- **Challenge-response**: Server sends nonce → client signs `endpoint_id + nonce` with Ed25519 → server verifies
- **TLS-PSK**: Optional, uses RFC 5705 Export Keying Material for faster session resume
- **Endpoint ID verification**: After relay establishes connection, the direct peer verifies the endpoint's signed ID
- **No replay protection on challenge**: If nonce is reused, same signature can replay

**Finding**: Challenge nonce reuse would enable replay attacks. Check if nonces are truly one-time.

### L4: Path Selection & Transport Multiplexing
- **BiasedRttPathSelector**: Sorts paths by `(transport_type, biased_rtt)`
- **Tier rules**: Primary (IP) > Backup (Relay). Cross-tier: switch immediately. Same-tier: 5ms threshold.
- **IPv6 bias**: 3ms RTT advantage hardcoded (configurable via `unstable-custom-transports` feature)
- **Multipath**: Min 14 paths clamped (in `QuicTransportConfig`), max idle timeout 15s/path
- **Polling fairness**: `Transports::poll_recv()` alternates forward/reverse order every 2nd call to prevent starvation

**Finding**: IPv6 bias is hardcoded — IPv4 users always at 3ms disadvantage. Not a security issue but a fairness concern.

### L5: Connection State Machine
- **Compile-time states**: `HandshakeCompleted`, `OutgoingZeroRtt`, `IncomingZeroRtt`
- **0-RTT**: `outgoing.into_0rtt()` sends data before handshake completes
- **Replay vulnerability**: 0-RTT data is vulnerable to replay — server may accept it after handshake completes
- **Stream limits**: Configurable via `QuicTransportConfigBuilder`
- **Idle timeout**: Max 15s per path (hard clamped)

**Finding**: 0-RTT is acknowledged as replay-vulnerable in docs. Server-side replay detection is responsibility of application layer — iroh does NOT enforce idempotency.

### L6: NAT Traversal
- **Protocols**: UPnP (most common), PCP (preferred but rare), NAT-PMP (Apple)
- **Port mapper config**: `Enabled` or `Disabled`
- **Hole punch interval**: Every 5s if no NAT candidate changes
- **Upgrade interval**: Every 60s even with working relay path
- **Good-enough latency**: Paths under 10ms are not upgraded

**Finding**: If hole punch interval is too frequent and NAT candidate detection is buggy, can cause NAT table exhaustion on home routers.

### L7: Address Resolution
- **PKARR**: Signed DNS-like records, published to Mainline DHT and relay servers
- **DNS**: TXT records under `_iroh.<z32-endpoint-id>.iroh.link`
- **Publisher**: Uses `n0_watcher` for endpoint info updates with exponential backoff
- **Resolver**: HTTPS requests to iroh.link /pkarr path, staggered timeouts
- **Staging domain**: Separate DNS for test-utils feature

**Finding**: PKARR records are signed by endpoint's own key — if DHT is eclipsed, attacker can serve fake records. No secondary verification channel.

## Security Assessment Summary

| Layer | Risk Level | Key Concern |
|-------|-----------|-------------|
| Crypto Identity | LOW | Immutable keys, no rotation |
| TLS | LOW | Insecure mode properly gated |
| Relay Auth | MEDIUM | Challenge nonce replay potential |
| Path Selection | LOW | Hardcoded IPv6 bias, relay fallback secure |
| Connection State | MEDIUM | 0-RTT replay responsibility deferred to app |
| NAT Traversal | MEDIUM | UPnP source validation needed |
| Address Resolution | MEDIUM | PKARR DHT eclipse risk |

## PoC Potential
- **Relay auth bypass**: Requires forging challenge nonce or exploiting TLS-PSK
- **0-RTT replay**: Can be proven in test environment with local relay
- **NAT exhaustion**: Requires actual network access to home router
- **PKARR eclipse**: Requires DHT infrastructure access

## Key Files Examined
- `iroh/src/endpoint/presets.rs` — Preset pattern, N0 bundle config
- `iroh/src/endpoint/connection.rs` — Connection state machine, 0-RTT handling
- `iroh/src/socket/transports.rs` — Transport multiplexing, polling fairness
- `iroh/src/socket/remote_map/remote_state.rs` — RemoteStateActor lifecycle
- `iroh/src/socket/biased_rtt_path_selector.rs` — Path selection algorithm
- `iroh-relay/src/tls.rs` — TLS config modes
- `iroh-relay/src/protos/handshake.rs` — Relay handshake proto
- `noq-udp/src/lib.rs` — UDP socket features (GSO, GRO, ECN, batch)
- `noq/Cargo.toml` — noq v1.1.0, Rust 2024, crypto deps
