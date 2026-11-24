# rev

Goal: recover the check, then satisfy it. Static first; dynamic when static stalls.

## Triage

```bash
file ./chal; checksec --file=./chal
strings -n 6 ./chal | head -50
rabin2 -I ./chal
```

Look for: flag comparisons, `strcmp`-family imports, base64 alphabets, XOR loops, `.rodata` blobs,
anti-debug (`ptrace`, `IsDebuggerPresent`), packers (high entropy, UPX magic).

## Static

`ghidra` → analyze → follow `main` → rename as you learn. Look at the string xrefs first; the
win condition is usually adjacent to a message.

For small checkers, a decompiler is faster than reasoning:

```bash
r2 -A ./chal -q -c 'afl; pdf @ main'
```

.NET: `dnSpy`/`ilspycmd`. Python: `pycdc`, `decompyle3`. APK: `jadx -d out app.apk`. Go: `go tool objdump`,
`redress`. Rust: symbol names survive `strings`.

## Dynamic

```bash
gdb -q ./chal -ex 'b *main' -ex run
ltrace -f ./chal       # library calls: strcmp, memcmp
strace -f ./chal       # syscalls
```

Patch the branch rather than reversing the math when it is a single `jne`: `r2 -w -c 's addr; wa jmp addr2'`.

`frida` for Android/desktop runtime hooks:

```javascript
Java.perform(() => {
  const C = Java.use("com.app.Check");
  C.verify.overload("java.lang.String").implementation = function (s) {
    console.log("input:", s); return true;
  };
});
```

## Symbolic execution

```python
import angr, claripy
p = angr.Project("./chal", auto_load_libs=False)
s = p.factory.entry_state()
sm = p.factory.simgr(s)
sm.explore(find=lambda st: b"Correct" in st.posix.dumps(1),
           avoid=lambda st: b"Wrong" in st.posix.dumps(1))
print(sm.found[0].posix.dumps(0))
```

If angr drowns, constrain the input length and alphabet first (`claripy` `regs`/stdin constraints).
z3 directly when the check is arithmetic on bytes.

## Anti-analysis

- `ptrace` self-attach: run under `gdb` with `set follow-fork-mode parent`, or patch the call.
- Timing checks: `LD_PRELOAD` shim over `clock_gettime`.
- VM detection: patch the `cpuid` branch.
- Obfuscated control flow: `deflat`, or trace with `qiling`/`unicorn` and log the comparisons.

## Deliverable

The keygen or the input, plus the three lines that explain the check. `chal_keygen.py` that prints
the accepted input, verified against the binary.
