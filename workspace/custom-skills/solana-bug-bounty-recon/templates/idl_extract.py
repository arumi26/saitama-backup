#!/usr/bin/env python3
"""Extract Anchor IDL from a Next.js JS bundle (embedded as JSON.parse('...'))."""
import sys, json

def extract_idl(js_path, program_id):
    with open(js_path, encoding='utf-8', errors='replace') as f:
        content = f.read()

    target = f'"address":"{program_id}"'
    idx = content.find(target)
    if idx < 0:
        return None

    # Walk back to find JSON.parse('
    parse_start = content.rfind('JSON.parse(', 0, idx)
    if parse_start < 0:
        return None

    i = parse_start + len("JSON.parse(") + 1  # skip opening quote (single quote)
    start = i

    # Read until unescaped closing single-quote
    while i < len(content):
        if content[i] == '\\':
            i += 2
            continue
        if content[i] == "'":
            break
        i += 1

    raw = content[start:i]
    # JS unicode-escape → Python
    unescaped = raw.encode().decode('unicode_escape')

    try:
        idl = json.loads(unescaped)
        return idl
    except json.JSONDecodeError as e:
        print(f"decode err: {e}", file=sys.stderr)
        return None


if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("usage: idl_extract.py <bundle.js> <program_id>")
        sys.exit(1)
    idl = extract_idl(sys.argv[1], sys.argv[2])
    if idl:
        json.dump(idl, sys.stdout, indent=2)
    else:
        print("IDL not found", file=sys.stderr)
        sys.exit(2)
