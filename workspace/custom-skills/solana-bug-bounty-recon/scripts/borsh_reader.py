#!/usr/bin/env python3
"""Minimal Borsh reader for Anchor accounts. No external deps except base58."""
import struct, base58

class BorshReader:
    def __init__(self, data):
        self.d = data
        self.p = 0
    def read(self, n):
        v = self.d[self.p:self.p+n]
        self.p += n
        return v
    def u8(self):  return self.read(1)[0]
    def u16(self): return struct.unpack('<H', self.read(2))[0]
    def u32(self): return struct.unpack('<I', self.read(4))[0]
    def u64(self): return struct.unpack('<Q', self.read(8))[0]
    def i64(self): return struct.unpack('<q', self.read(8))[0]
    def bool(self): return self.u8() != 0
    def pubkey(self): return base58.b58encode(self.read(32)).decode()
    def string(self):
        n = self.u32()
        return self.read(n).decode('utf-8', errors='replace')
    def option(self, inner):
        tag = self.u8()
        if tag == 0: return None
        elif tag == 1: return inner()
        else: raise ValueError(f"option tag {tag}")
    def vec(self, inner):
        n = self.u32()
        return [inner() for _ in range(n)]

# Usage:
# with open('account.bin','rb') as f: raw = f.read()
# r = BorshReader(raw[8:])  # skip 8-byte discriminator
# creator = r.pubkey()
# created_at = r.i64()
# etc, following IDL account struct field order
