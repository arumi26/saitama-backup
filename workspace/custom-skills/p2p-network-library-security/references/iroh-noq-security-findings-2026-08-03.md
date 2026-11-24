# Iroh/Noq Security Findings — Session 2026-08-03

## NAT Traversal Protocol (`n0_nat_traversal.rs`)

### FINDING-1: Probe Amplification (MEDIUM)
- **Location**: `n0-proto/src/n0_nat_traversal.rs`, `MAX_NAT_PROBE_ATTEMPTS = 9`
- **Issue**: Each NAT traversal round sends up to 9 probes per remote address with exponential backoff (~33ms base, max 2s). Server-side, `ServerState` probes back to ALL client addresses in a round.
- **Impact**: An attacker initiating many connections can trigger thousands of outbound UDP probes from the server.
- **Mitigation**: Rate limiting on `REACH_OUT` frames, cap on probes per connection.

### FINDING-2: REACH_OUT Address Spoofing (LOW)
- **Location**: `ServerState::handle_reach_out()`
- **Issue**: Client can send `ReachOut` frames with arbitrary IP/port. Server will probe these addresses without pre-validation.
- **Impact**: Amplification attack vector — server probes attacker-chosen addresses.
- **Mitigation**: Existing `max_remote_addresses` limit bounds damage but doesn't prevent per-frame CPU cost.

### FINDING-3: IPv4-mapped IPv6 Canonicalization Bypass (LOW)
- **Location**: `map_to_local_socket_family()`, `CanonicalIpPort`
- **Issue**: IPv4 addresses are mapped to IPv6-mapped form when socket supports IPv6. If canonicalization is inconsistent between check and use, address matching can be bypassed.
- **Impact**: Potential path validation bypass in NAT traversal.
- **Note**: Code uses `CanonicalIpPort` consistently, but `check_remote_address()` does comparison after mapping — risk is low but worth monitoring.

### FINDING-4: Linear Search in Path Response Validation (LOW)
- **Location**: `ClientState::handle_path_response()`
- **Issue**: O(n) linear search through `remote_addresses` to find sequence number by IP.
- **Impact**: DoS via slow path response processing in connections with many remote addresses.
- **Mitigation**: `FxHashMap` lookup by seq_no is O(1); linear search only happens after successful match.

## Token System (`token.rs`)

### FINDING-5: NEW_TOKEN IP-Only Binding (MEDIUM)
- **Location**: `TokenPayload::Validation { ip, issued }`
- **Issue**: Validation tokens bind only to IP address, not port. Under CGNAT (RFC 6598), multiple users share the same public IP.
- **Impact**: A validation token obtained by one CGNAT user could be used by another user sharing the same public IP.
- **Mitigation**: Token lifetime limits reduce window. For high-security apps, combine with additional binding (e.g., TLS session ID).

### FINDING-6: TokenLog False Negative = DDoS Amplification (MEDIUM)
- **Location**: `TokenLog::check_and_insert()` trait contract
- **Issue**: RFC 9000 §8.1.4 explicitly acknowledges that false negatives (accepting a reused token) could enable DDoS amplification. The `NoneTokenLog` rejects ALL tokens.
- **Impact**: Any `TokenLog` implementation that does not properly deduplicate nonces within the token lifetime opens the server to amplification.
- **Note**: iroh exposes `TokenLog` as a configurable trait — the default/insecure implementation is the operator's responsibility.

### FINDING-7: Retry Token LB Address Mismatch (INFO)
- **Location**: `TokenPayload::Retry { address, ... }`, `address != remote_address` check
- **Issue**: If server is behind a load balancer, `remote_address` in the incoming packet is the LB's address, not the original client. Retry tokens will always fail validation.
- **Impact**: Degradation only (connection proceeds without validated address), not bypass. Safe by default.

## QUIC Crypto Layer (`crypto.rs`)

### FINDING-8: TLS-PSK Export Label Uniqueness (LOW)
- **Location**: `Session::export_keying_material()` used for relay authentication
- **Issue**: iroh uses `"iroh relay"` label for TLS-PSK export (RFC 5705). This label is not domain-separated from QUIC crypto key material.
- **Impact**: Theoretical cross-protocol attack if the same TLS session is used for both QUIC and relay transport with shared key material.
- **Note**: QUIC and relay use separate `Session` instances — practical risk is minimal.

### FINDING-9: 0-RTT Key Exposure Window (LOW)
- **Location**: `Session::early_crypto()` returns `(HeaderKey, PacketKey)`
- **Issue**: 0-RTT keys available before handshake verification. iroh handles this with `ZeroRttStatus::Rejected` but the raw `noq` layer exposes keys directly.
- **Impact**: Application using `noq` directly must implement its own 0-RTT rejection logic.
- **Mitigation**: iroh's `Connection` wrapper enforces 0-RTT awareness via `RecvStream::is_0rtt()` check.

## Frame Protocol (`frame.rs`)

### FINDING-10: Unknown Frame Type = Forced Connection Close (LOW)
- **Location**: `FrameType::try_from(u64)` → `InvalidFrameId` → connection error
- **Issue**: Receiving an unknown frame type triggers `InvalidFrameId` error, which closes the connection.
- **Impact**: Attacker can send random unknown frame types to force connection drops → DoS.
- **Mitigation**: QUIC RFC 9000 §19.16 requires connection close on unknown frame types. This is by design, not a bug.

### FINDING-11: AddAddress Parse Cost Without Rate Limit (LOW)
- **Location**: `FrameType::AddIpv4Address (0x3d7f90)`, `FrameType::AddIpv6Address (0x3d7f91)`
- **Issue**: Each `AddAddress` frame is parsed and processed. While `max_remote_addresses` limits total stored, every parse still consumes CPU.
- **Impact**: Flooding with AddAddress frames → CPU exhaustion.
- **Mitigation**: `max_remote_addresses` bounds the impact. QUIC flow control applies to frame processing.

## Connection Lifecycle (`connection.rs`)

### FINDING-12: Type-State Compile-Time Safety (POSITIVE)
- **Location**: `Connection<State: ConnectionState>`
- **Issue**: Connection uses Rust type-state pattern to prevent state machines from being used incorrectly at compile time.
- **Impact**: Eliminates entire classes of runtime state bugs (e.g., using `Connection<OutgoingZeroRtt>` as fully established).

## Summary Table

| Finding | Severity | Module | CWE |
|---------|----------|--------|-----|
| Probe Amplification | MEDIUM | NAT Traversal | CWE-400 |
| REACH_OUT Spoofing | LOW | NAT Traversal | CWE-294 |
| IPv6 Canonicalization | LOW | NAT Traversal | CWE-697 |
| Linear Search DoS | LOW | NAT Traversal | CWE-400 |
| CGNAT Token Leak | MEDIUM | Token System | CWE-287 |
| TokenLog Amplification | MEDIUM | Token System | CWE-400 |
| Retry Token LB Mismatch | INFO | Token System | — |
| TLS-PSK Label | LOW | Crypto | CWE-327 |
| 0-RTT Key Exposure | LOW | Crypto | CWE-347 |
| Unknown Frame Close | LOW | Frame Protocol | CWE-915 |
| AddAddress Parse Cost | LOW | Frame Protocol | CWE-400 |
| Type-State Safety | POSITIVE | Connection | — |
