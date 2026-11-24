#!/usr/bin/env python3
"""
Compute Anchor discriminators for instructions and account types.

Anchor uses:
    ix discriminator      = sha256("global:<snake_case_name>")[:8]
    account discriminator = sha256("account:<PascalCaseName>")[:8]
    event discriminator   = sha256("event:<PascalCaseName>")[:8]

Usage:
    python3 anchor_discriminator.py <kind> <name>
        kind: ix | account | event

Or import:
    from anchor_discriminator import ix_disc, account_disc, event_disc
"""
import hashlib
import sys


def _disc(prefix: str, name: str) -> bytes:
    return hashlib.sha256(f"{prefix}:{name}".encode()).digest()[:8]


def ix_disc(name: str) -> bytes:
    return _disc("global", name)


def account_disc(name: str) -> bytes:
    return _disc("account", name)


def event_disc(name: str) -> bytes:
    return _disc("event", name)


def build_lookup_from_idl(idl: dict) -> dict:
    """Return {hex_string: (kind, name)} for every ix/account/event in an IDL."""
    out = {}
    for ix in idl.get('instructions', []):
        d = bytes(ix.get('discriminator', ix_disc(ix['name'])))
        out[d.hex()] = ('ix', ix['name'])
    for acc in idl.get('accounts', []):
        d = bytes(acc.get('discriminator', account_disc(acc['name'])))
        out[d.hex()] = ('account', acc['name'])
    for evt in idl.get('events', []):
        d = bytes(evt.get('discriminator', event_disc(evt['name'])))
        out[d.hex()] = ('event', evt['name'])
    return out


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    kind, name = sys.argv[1], sys.argv[2]
    fn = {'ix': ix_disc, 'account': account_disc, 'event': event_disc}.get(kind)
    if not fn:
        print(f"❌ unknown kind: {kind}")
        sys.exit(2)
    d = fn(name)
    print(f"hex:    {d.hex()}")
    print(f"bytes:  {list(d)}")
    try:
        import base58
        print(f"base58: {base58.b58encode(d).decode()}  (use as memcmp filter)")
    except ImportError:
        pass
