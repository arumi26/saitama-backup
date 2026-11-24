#!/usr/bin/env python3
"""
BIN/IIN Lookup — offline reference + Luhn validation
Usage: python3 bin_lookup.py <BIN_digits>
       python3 bin_lookup.py --luhn <full_card_number>
"""

import sys
import json

# ── Known BIN Ranges (excerpt — comprehensive version in references/bin_ranges.json) ──
# Format: (start, end, scheme, type, level_hint, country_code, bank_hint)
BIN_RANGES = [
    # Amex
    (340000, 349999, "amex", "credit", "Standard", "US", "American Express"),
    (370000, 379999, "amex", "credit", "Standard", "US", "American Express"),
    # Visa
    (400000, 499999, "visa", "credit", "Standard", "US", "Visa"),
    # Mastercard (5-series)
    (510000, 559999, "mastercard", "credit", "Standard", "EU", "Mastercard"),
    # Mastercard (2-series)
    (220000, 299999, "mastercard", "credit", "Standard", "EU", "Mastercard"),
    # Discover
    (601100, 601199, "discover", "credit", "Standard", "US", "Discover"),
    (644000, 649999, "discover", "credit", "Standard", "US", "Discover"),
    (650000, 659999, "discover", "credit", "Standard", "US", "Discover"),
    # JCB
    (352800, 358999, "jcb", "credit", "Standard", "JP", "JCB"),
    # UnionPay
    (620000, 629999, "unionpay", "credit", "Standard", "CN", "China UnionPay"),
    (810000, 829999, "unionpay", "credit", "Standard", "CN", "China UnionPay"),
    # Diners Club
    (300000, 305999, "diners", "credit", "Standard", "US", "Diners Club"),
    (360000, 369999, "diners", "credit", "Standard", "US", "Diners Club"),
    (380000, 389999, "diners", "credit", "Standard", "US", "Diners Club"),
    # Test cards (issuer-provided)
    (424242, 424242, "visa", "credit", "test", "US", "Stripe Test"),
    (555555, 555555, "mastercard", "credit", "test", "US", "Stripe Test"),
]


def luhn_check(card: str) -> bool:
    """Validate card number using Luhn algorithm."""
    digits = [int(d) for d in card if d.isdigit()]
    if len(digits) < 13:
        return False
    # Process from rightmost digit
    odd_sum = sum(digits[-1::-2])
    even_digits = digits[-2::-2]
    even_sum = 0
    for d in even_digits:
        doubled = d * 2
        even_sum += doubled // 10 + doubled % 10  # sum of digits
    return (odd_sum + even_sum) % 10 == 0


def lookup_bin(bin_digits: str) -> dict:
    """Look up BIN/IIN and return card info."""
    bin_val = int(bin_digits)
    matched = None
    for (start, end, scheme, ctype, level, country, bank) in BIN_RANGES:
        if start <= bin_val <= end:
            matched = {
                "scheme": scheme.upper(),
                "type": ctype,
                "level": level,
                "bank": bank,
                "country": country,
                "bin": bin_digits,
            }
            break
    if not matched:
        matched = {
            "scheme": "UNKNOWN",
            "type": "unknown",
            "level": "unknown",
            "bank": "Unknown issuer",
            "country": "??",
            "bin": bin_digits,
        }
    return matched


def luhn_generate(prefix: str, length: int = 16) -> str:
    """Generate a Luhn-valid number with given prefix (dummy only)."""
    partial = prefix + "0" * (length - len(prefix) - 1)
    digits = [int(d) for d in partial]
    odd_sum = sum(digits[-1::-2])
    even_sum = 0
    for d in digits[-2::-2]:
        doubled = d * 2
        even_sum += doubled // 10 + doubled % 10
    check = (10 - (odd_sum + even_sum) % 10) % 10
    return partial[:-1] + str(check)


def main():
    if len(sys.argv) < 2:
        print("Usage:")
        print("  python3 bin_lookup.py <BIN_6digits>")
        print("  python3 bin_lookup.py --luhn <full_card>")
        print("  python3 bin_lookup.py --generate <prefix>")
        sys.exit(1)

    arg = sys.argv[1]
    if arg == "--luhn" and len(sys.argv) > 2:
        card = sys.argv[2].replace(" ", "").replace("-", "")
        result = luhn_check(card)
        bin6 = card[:6] if len(card) >= 6 else card
        info = lookup_bin(bin6)
        print(f"\n{'='*50}")
        print(f"Card: {card}")
        print(f"BIN:  {bin6}")
        print(f"Luhn: {'✓ VALID' if result else '✗ INVALID'}")
        print(f"Scheme: {info['scheme']}")
        print(f"Type:   {info['type']}")
        print(f"Bank:   {info['bank']}")
        print(f"{'='*50}\n")
    elif arg == "--generate" and len(sys.argv) > 2:
        prefix = sys.argv[2].replace(" ", "").replace("-", "")
        if not prefix.isdigit() or len(prefix) < 6:
            print("Error: prefix must be at least 6 digits")
            sys.exit(1)
        result = luhn_generate(prefix)
        info = lookup_bin(prefix[:6])
        print(f"\n{'='*50}")
        print(f"Prefix: {prefix}")
        print(f"Result: {result}")
        print(f"Luhn:   {'✓ VALID' if luhn_check(result) else '✗ INVALID'}")
        print(f"Scheme: {info['scheme']}")
        print(f"Note:   Dummy generation for educational purposes ONLY")
        print(f"{'='*50}\n")
    else:
        bin6 = arg.replace(" ", "").replace("-", "")[:8]
        if not bin6.isdigit() or len(bin6) < 6:
            print("Error: provide at least 6 digits")
            sys.exit(1)
        info = lookup_bin(bin6)
        print(f"\n{'='*50}")
        print(f"BIN:    {bin6}")
        print(f"Scheme: {info['scheme']}")
        print(f"Type:   {info['type']}")
        print(f"Level:  {info['level']}")
        print(f"Bank:   {info['bank']}")
        print(f"Country:{info['country']}")
        print(f"{'='*50}\n")


if __name__ == "__main__":
    main()
