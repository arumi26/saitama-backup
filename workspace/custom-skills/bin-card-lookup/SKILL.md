
# BIN Card Lookup — IIN/BIN Validation Tool

Quick reference for looking up BIN/IIN ranges and validating partial card numbers for security research.

## Quick Commands

```bash
# Lookup BIN → scheme, type, bank, country
python3 ~/.hermes/skills/red-teaming/bin-card-lookup/scripts/bin_lookup.py 553890

# Validate Luhn check digit
python3 ~/.hermes/skills/red-teaming/bin-card-lookup/scripts/bin_lookup.py --luhn "5154620022000000"

# Generate Luhn-valid dummy number (educational)
python3 ~/.hermes/skills/red-teaming/bin-card-lookup/scripts/bin_lookup.py --generate 123456789012
```

## Online API (faster, more complete data)

```bash
curl -s "https://binlist.net/qr/553890"
curl -s "https://api.visainfantech.com/v1/bin/553890"
```

## Known BIN Ranges (Offline Reference)

| Field | Description |
|-------|-------------|
| `scheme` | Visa, Mastercard, Amex, Discover, JCB, UnionPay, etc. |
| `type` | Credit, Debit, Prepaid, Charge |
| `level` | Classic, Gold, Platinum, International, etc. |
| `bank` | Issuing bank name |
| `website` | Bank URL |
| `phone` | Bank contact |
| `country` | ISO code + name + currency |
| `valid` | Luhn check + BIN range match |

## Known BIN Reference (Common Ranges)

```
# Amex
34xxx / 37xxx — American Express

# Visa
4xxx — Visa (all lengths)

# Mastercard
51-55xxx — Mastercard Standard
2xxx — Mastercard (new 2-series)

# Discover
6011xxx, 644-649xxx, 65xxx — Discover

# JCB
3528-3589xxx — JCB

# UnionPay
62xx, 81xx — UnionPay (China)

# Diners Club
300-305xxx, 36xxx, 38-39xxx — Diners
```

## Legitimate Use Cases

- **Bug bounty**: Identify prepaid/test cards in payment flows (often weaker controls)
- **PCI-DSS audit**: Verify BIN ranges match expected issuing banks
- **Fraud detection**: Cross-reference BIN with transaction country
- **Payment integration testing**: Validate test card numbers per scheme rules
- **Card scheme compliance**: Check 6-digit BIN against issuer registry

## Anti-Abuse Guardrails

❌ **NOT for**: Generating valid card numbers, carding, CVV stuffing, account takeover  
✅ **IS for**: Research, validation, educational purposes on your own systems

Luhn algorithm is built-in — use it to verify check-digit validity only on cards you own/test.

## Luhn Validation (Python)

```python
def luhn_check(card: str) -> bool:
    """Return True if card number passes Luhn algorithm."""
    digits = [int(d) for d in card if d.isdigit()]
    if len(digits) < 13:
        return False
    odd_sum = sum(digits[-1::-2])
    even_sum = sum(sum(divmod(2 * int(d), 10)) for d in digits[-2::-2])
    return (odd_sum + even_sum) % 10 == 0

# Usage
print(luhn_check("4111111111111111"))  # Test card — True
print(luhn_check("5154620022000000"))  # Example BIN — True
```

## Common Test BINs (Issuer Provided)

| BIN | Scheme | Type | Use |
|-----|--------|------|-----|
| 4242 4242 4242 4242 | Visa | Credit | Stripe test |
| 4000 0566 5566 5556 | Visa | Debit | Stripe test |
| 5555 5555 5555 4444 | MC | Credit | Stripe test |
| 3782 8224 6310 005 | Amex | Credit | Stripe test |
| 6011 1111 1111 1117 | Discover | Credit | Stripe test |

> ⚠️ These are **issuer-provided test numbers** for payment gateway development. Never use on production.

## References

- [Binlist.net API](https://binlist.net/) — open BIN database (no auth required for basic lookups)
- [ISO 7812](https://en.wikipedia.org/wiki/ISO/IEC_7812) — IIN/BIN standard
- [PCI Card Security](https://www.pcisecuritystandards.org/) — official scheme rules
