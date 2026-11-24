# CTF

A CTF is a bounded exploit with a proof string. The bound is the challenge; the proof is the flag.
Work the bound, not the theory.

## Rules of engagement

- The scope is the challenge artifacts. Nothing else on the host is fair game unless the challenge
  says so.
- Flag format is stated on the platform page. Read it before hunting, not after.
- One challenge at a time. Timebox: 20 minutes to first signal, then switch or ask. A stuck
  challenge costs more than a skipped one.
- Keep every artifact. The writeup is part of the work.

## Workspace

```
chal/
  artifacts/      # original files, never edited
  notes.md        # hypothesis log, timestamps
  exploit/        # scripts
  proof/          # flag, shell output, screenshots
```

Hash the artifacts into `notes.md` on arrival. If the challenge is remote, record host:port and
the exact connection line.

## Triage tree

1. **Identify** — `file`, `checksec`, `binwalk`, `exiftool`, `strings -n 8`. Architecture first,
   always.
2. **Classify** — which reference below, by artifact type and by what the description implies.
3. **Local first** — reproduce locally before touching remote. A remote that behaves differently
   means the local setup is wrong, not that the exploit changed.
4. **Signal** — a crash with controlled RIP, an injection that reflects, a decryption that yields
   ASCII. No signal in 20 minutes → change class or ask.
5. **Exploit** — smallest payload that proves the primitive, then weaponize.
6. **Proof** — capture the flag and the command that produced it verbatim.

## Categories

| Reference | Load when |
| --- | --- |
| `references/pwn.md` | ELF/PE binary with a service, crash, `nc` handout, seccomp |
| `references/web.md` | URL, source tree, PHP/Flask/Node, cookies, JWT |
| `references/rev.md` | Crackme, license check, obfuscated binary, APK, .NET, pyc |
| `references/crypto.md` | Ciphertext, RSA parameters, custom PRNG, "many messages" |
| `references/forensics.md` | pcap, memory image, disk image, stego carrier |
| `references/misc.md` | pyjail, bash jail, esolang, QR, "no category fits" |

## Environment

```bash
python -m venv .venv && . .venv/bin/activate
pip install pwntools z3-solver angr pycryptodome gmpy2 requests
# system: gdb + pwndbg, ghidra, binwalk, tshark, volatility3, sleuthkit, exiftool, radare2
```

Pin what you install into `notes.md`. A payload that needs a version is not a payload without one.

## pwn skeleton

```python
from pwn import *
context.binary = elf = ELF("./chal", checksec=False)
context.log_level = "info"
io = process(elf.path) if args.LOCAL else remote(HOST, PORT)
# exploit
io.interactive()
```

## Writeup contract

Name the primitive, the offset, the mitigation bypass, and the flag. Include the failing attempt
that taught you the offset. Four sections, no narrative padding:

```
## Primitive        stack overflow at offset 72, no canary
## Bypass           ret2libc via leaked puts@GOT
## Exploit          exploit/x.py, one-shot
## Flag             flag{...}
```

## Common traps

- Off-by-one in the offset because the payload was built for the wrong arch.
- Testing remote before local, burning the only service instance.
- Assuming a libc version instead of `libc-database` / `one_gadget` on the provided one.
- Forgetting endianness on a big-endian target.
- `interactive()` before the shell is stable; use `io.sendline(b"id")` to confirm first.
