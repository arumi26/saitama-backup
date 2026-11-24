#!/usr/bin/env python3
"""
Extract Anchor IDL from a Next.js frontend JS bundle.

Usage:
    python3 extract_idl_from_bundle.py <bundle.js> <program_id> [out.json]

The IDL is typically embedded as `JSON.parse('{...}')` — a JS single-quoted
string with escapes. We locate the `"address":"<PROGRAM_ID>"` marker, walk
back to the containing `{`, decode JS-string escapes, then json.loads.
"""
import sys, json, re


def extract_idl(bundle_path: str, program_id: str) -> dict | None:
    with open(bundle_path, encoding='utf-8', errors='replace') as f:
        content = f.read()

    # Look for the double-escaped address literal inside JSON.parse('...')
    escaped = f'\\"address\\":\\"{program_id}\\"'
    idx = content.find(escaped)
    if idx < 0:
        # Fallback: raw form (rare — some builds don't wrap in JSON.parse)
        raw = f'"address":"{program_id}"'
        idx = content.find(raw)
        if idx < 0:
            return None
        return _decode_raw(content, idx)

    return _decode_json_parse(content, idx)


def _decode_json_parse(content: str, hit_idx: int) -> dict | None:
    # Walk back to find `JSON.parse(` then the opening quote
    parse_start = content.rfind("JSON.parse(", 0, hit_idx)
    if parse_start < 0:
        return None
    # Skip whitespace after (
    i = parse_start + len("JSON.parse(")
    while i < len(content) and content[i] in ' \n\t':
        i += 1
    quote = content[i]
    if quote not in ("'", '"'):
        return None
    i += 1
    start = i
    # Find matching close quote, honouring backslash escapes
    while i < len(content):
        if content[i] == '\\':
            i += 2
            continue
        if content[i] == quote:
            break
        i += 1
    raw_str = content[start:i]
    # Decode JS single-quoted string → real JSON text
    unescaped = raw_str.encode().decode('unicode_escape')
    return json.loads(unescaped)


def _decode_raw(content: str, hit_idx: int) -> dict | None:
    # Walk back to find the containing `{`, then try raw_decode
    decoder = json.JSONDecoder()
    for back in range(1, 500):
        pos = hit_idx - back
        if pos < 0:
            return None
        if content[pos] != '{':
            continue
        try:
            obj, _ = decoder.raw_decode(content, pos)
            if isinstance(obj, dict) and 'instructions' in obj:
                return obj
        except json.JSONDecodeError:
            continue
    return None


def summarise(idl: dict) -> None:
    print(f"Program: {idl.get('address')}")
    meta = idl.get('metadata', {})
    print(f"Name:    {meta.get('name')} v{meta.get('version')} (spec {meta.get('spec')})")
    print(f"Instructions: {len(idl.get('instructions', []))}")
    print(f"Accounts:     {len(idl.get('accounts', []))}")
    print(f"Errors:       {len(idl.get('errors', []))}")
    print(f"Events:       {len(idl.get('events', []))}")
    print(f"Types:        {len(idl.get('types', []))}")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)
    bundle, program_id = sys.argv[1], sys.argv[2]
    out = sys.argv[3] if len(sys.argv) > 3 else 'idl.json'
    idl = extract_idl(bundle, program_id)
    if not idl:
        print(f"❌ Could not find IDL for {program_id} in {bundle}")
        sys.exit(2)
    with open(out, 'w') as f:
        json.dump(idl, f, indent=2)
    print(f"✅ IDL saved to {out}")
    summarise(idl)
