# Consensus Code Audit Methodology

## When to Apply
- Target is a blockchain consensus protocol (Solana, Ethereum L2, etc.)
- Bug bounty competition with specific scope rules
- Rust/C++ codebase with complex state machines

## Workflow

### 1. Clone and Navigate
```bash
git clone --depth=1 --filter=blob:none https://github.com/ORG/REPO.git
find . -name "*.rs" -path "*/consensus/*" -o -name "*.rs" -path "*/votor/*"
```

### 2. Check Known Issues (OUT OF SCOPE)
```bash
curl -s "https://api.github.com/repos/ORG/REPO/issues?labels=consensus,blocking&state=open" | \
  jq -r '.[] | "#\(.number) | \(.title) | \(.state)"'
```
**Rule:** If issue is OPEN and public, it's OUT OF SCOPE for competition.

### 3. Map Attack Surface
Focus on:
- Vote aggregation logic
- Certificate verification
- State machine transitions
- Reward calculation
- Timeout/standstill handling
- Migration logic (if applicable)

### 4. Search for Vulnerability Patterns

#### Integer Overflow/Underflow
```bash
grep -rn "as u64\|as usize\|wrapping_\|saturating_\|checked_" --include="*.rs" | grep -v "test\|//"
```

#### Unwrap/Panic (DoS vector)
```bash
grep -rn "unwrap\|expect\|panic\|unreachable" --include="*.rs" | grep -v "test\|//"
```

#### Threshold Checks
```bash
grep -rn "threshold\|stake\|supermajority\|2/3\|67\|33" --include="*.rs" | grep -v "test\|//"
```

#### State Machine Transitions
```bash
grep -rn "assert\|assert_eq\|assert_ne" --include="*.rs" | grep -v "test\|//"
```

### 5. Analyze State Machines
- Map all possible states
- Map all transitions between states
- Check for missing transitions
- Check for unreachable states
- Check for deadlock conditions

### 6. Check Equivocation Detection
- Verify vote pool prevents double-voting
- Check per-rank voting history
- Verify bitmap prevents duplicate signatures

### 7. Check Reward Calculations
- Verify slot arithmetic uses saturating_add
- Check for off-by-one errors
- Verify threshold comparisons use Fraction type

## Key Patterns (Solana Alpenglow)

### Overflow Protection
```rust
// GOOD: saturating_add prevents overflow
self.stake = self.stake.saturating_add(aggregate.stake().get());

// BAD: regular addition could overflow
self.stake = self.stake + aggregate.stake().get();
```

### Equivocation Detection
```rust
// GOOD: Check for duplicate rank before adding
if self.ranks.replace(msg.rank as usize, true) {
    return Err(AggregateAccumulatorError::Duplicate);
}
```

### Threshold Comparison
```rust
// GOOD: Use Fraction type for precise comparison
let observed_fraction = Fraction::new(self.stake, total_stake);
if observed_fraction >= cert_type.threshold() {
    // Certificate is valid
}
```

## Pitfalls

### Known Issues Are OUT OF SCOPE
- Competition rules explicitly exclude public GitHub issues
- OPEN issues = unfixed but known = OUT OF SCOPE
- CLOSED issues = fixed = can't submit either

### Well-Audited Code = Low ROI
- 20K lines of Rust with 0 critical bugs = pivot
- Multiple audits + active team = bugs already found
- Use Breach Mode for out-of-the-box thinking

### RPC Services Don't Hold Funds
- RPC services (BlockPI, Alchemy, Infura) = no fund theft potential
- Target actual DeFi protocols (lending, bridge, DEX) for fund theft bugs

### Don't Submit False Positives
- Verify every finding with PoC
- Check if finding is already tracked in known issues
- False positives damage reputation

## Breach Mode (When Code Audit Yields 0 Bugs)

If code audit finds nothing after 2+ hours, think BEYOND code:

### Economic Attacks
- Flash loan + stake manipulation
- Epoch boundary exploitation
- Reward calculation rounding errors
- Stake delegation manipulation

### Serialization Attacks
- Wire format edge cases
- Deserialization panics
- Integer overflow in length fields
- Encoding confusion

### Concurrency Attacks
- Channel saturation
- Lock contention
- Thread ordering manipulation
- Deadlock induction

### Integration Attacks
- Cross-component state desync
- Migration edge cases
- Snapshot/restore attacks
- Feature flag interactions

### Network Attacks
- Message reordering/delay/duplication
- Eclipse/Sybil/partition attacks
- Connection exhaustion

### Cryptographic Attacks
- Signature malleability
- Key reuse across contexts
- Timing attacks on verification

### Workflow
1. Code audit first
2. If 0 bugs → activate Breach Mode
3. Attack assumptions, boundaries, interactions
4. Think like an attacker, not a defender
