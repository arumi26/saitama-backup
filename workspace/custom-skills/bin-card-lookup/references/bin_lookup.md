# BIN Card Lookup — Reference Files

## Scripts

### `scripts/bin_lookup.py`
Offline BIN/IIN lookup with three modes:

```bash
# Lookup BIN → scheme, type, bank, country
python3 scripts/bin_lookup.py 553890

# Validate Luhn check digit
python3 scripts/bin_lookup.py --luhn "5154620022000000"

# Generate Luhn-valid number (educational only)
python3 scripts/bin_lookup.py --generate 123456789012
```

## Known BIN Ranges (from skill)

| Range | Scheme | Type |
|-------|--------|------|
| 34-37xxx | Amex | Credit |
| 4xxx | Visa | Credit/Debit |
| 51-55xxx | Mastercard | Credit |
| 2xxx | Mastercard | Credit (2-series) |
| 6011/644-649/65xxx | Discover | Credit |
| 3528-3589xxx | JCB | Credit |
| 62xx, 81xx | UnionPay | Credit |
| 300-305/36/38-39xxx | Diners Club | Credit |

## Test Cards (Issuer-Provided)

| Number | CVV | Exp | Source |
|--------|-----|-----|--------|
| 4242 4242 4242 4242 | 123 | 12/30 | Stripe |
| 5555 5555 5555 4444 | 123 | 12/30 | Stripe |
| 3782 8224 6310 005 | 1234 | 12/30 | Stripe |
| 6011 1111 1111 1117 | 123 | 12/30 | Stripe |

## API References

- **Binlist.net**: `curl -s https://binlist.net/qr/<BIN>` (no auth required)
- **Visa Infantech**: `curl -s https://api.visainfantech.com/v1/bin/<BIN>`

## Educational Note

Luhn generation creates mathematically valid numbers but does NOT produce usable cards. Real card validation requires:
- Issuer verification (ACV/CVV checks)
- Account status lookup
- Fraud screening

This tool is for understanding the algorithm and testing payment form validation, not for generating usable payment instruments.
