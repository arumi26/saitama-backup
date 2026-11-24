#!/usr/bin/env python3
"""
Minimal Borsh reader for Anchor account data.

Usage in your decoder script:

    from borsh_reader import BorshReader

    def decode_launch(raw):
        # Skip 8-byte Anchor discriminator
        r = BorshReader(raw[8:])
        return {
            'creator':    r.pubkey(),
            'created_at': r.i64(),
            'slot':       r.u64(),
            'name':       r.string(),
            'symbol':     r.string(),
            'uri':        r.string(),
            'mint':       r.pubkey(),
            'phase':      r.u8(),
            'participants_count': r.u32(),
            'gacha_started_at':   r.option(r.i64),
            # ...
        }

Reader is stateful — reads consume bytes sequentially. Field order MUST
match the IDL's Launch.type.fields.
"""
import struct
import base58


class BorshReader:
    def __init__(self, data: bytes):
        self.d = data
        self.p = 0

    def read(self, n: int) -> bytes:
        if self.p + n > len(self.d):
            raise ValueError(f"read({n}) past end at offset {self.p}, have {len(self.d)}")
        v = self.d[self.p:self.p + n]
        self.p += n
        return v

    # ── primitives ─────────────────────────────────────────────
    def u8(self):  return self.read(1)[0]
    def u16(self): return struct.unpack('<H', self.read(2))[0]
    def u32(self): return struct.unpack('<I', self.read(4))[0]
    def u64(self): return struct.unpack('<Q', self.read(8))[0]
    def i8(self):  return struct.unpack('<b', self.read(1))[0]
    def i32(self): return struct.unpack('<i', self.read(4))[0]
    def i64(self): return struct.unpack('<q', self.read(8))[0]
    def bool(self): return self.u8() != 0

    def pubkey(self) -> str:
        return base58.b58encode(self.read(32)).decode()

    def string(self) -> str:
        n = self.u32()
        return self.read(n).decode('utf-8', errors='replace')

    def bytes_var(self) -> bytes:
        n = self.u32()
        return self.read(n)

    def option(self, inner):
        """Borsh Option: 1-byte tag + inner if present."""
        tag = self.u8()
        if tag == 0:
            return None
        if tag == 1:
            return inner()
        raise ValueError(f"invalid option tag {tag} at offset {self.p - 1}")

    def vec(self, inner):
        n = self.u32()
        return [inner() for _ in range(n)]

    def fixed_array(self, inner, count):
        return [inner() for _ in range(count)]

    # ── helpers ─────────────────────────────────────────────
    def remaining(self) -> int:
        return len(self.d) - self.p

    def peek(self, n: int) -> bytes:
        return self.d[self.p:self.p + n]
