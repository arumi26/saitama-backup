# misc

Everything without a category. Read the jail, do not guess the jail.

## Python jail

```python
print(open("/flag").read())
().__class__.__base__.__subclasses__()      # walk to a file reader
[].__class__.__base__.__subclasses__()[N].__init__.__globals__["__builtins__"]
```

Useful gadgets when `__builtins__` is stripped: `breakpoint()` (pdb → `!` shell), `help()`,
`license()`, `_` in the REPL (last result), `vars()`/`dir()` on live objects, `getattr` via
`().__getattribute__("__class__")`, and `compile`/`eval` through a subclass's globals.

Blocked quotes: `chr(39)`, `"%c"`. Blocked brackets: `().__class__.__mro__[1].__getattribute__("__subclasses__")()`.
No underscores: `getattr(obj, "_"*2 + "class" + "_"*2)`. `eval` blocked: `exec`, `compile`, or
`__import__("os").system`.

When the interpreter is gone but an import survives: `__import__("pty").spawn("/bin/sh")`.

## Bash jail

`$0`, `${PATH:0:1}`, globbing for letters (`/???/??/ls`), `$(<file)`, `cat${IFS}/flag`. Restricted
shell with only `echo`: `echo $(</flag)`. Only `vi`: `:!sh`. Only `less`: `!sh`.

## Encoding / esolangs

Identify first — `file`, magic bytes, a known alphabet. Brainfuck, Malbolge, Piet, Whitespace,
Ook. `cyberchef` recipes handle chains; for a custom alphabet, `freq`-match against English.

## QR / barcode

`zbarimg`, `qrdecode`. Damaged QR: reconstruct finder patterns, or read the version/EC level and
brute the missing modules.

## OSINT-lite

EXIF GPS (`exiftool -a -G1`), Wayback (`web.archive.org/cdx/search/cdx?url=`), certificate
transparency (`crt.sh`), GitHub dorking for a leaked key. Geoguessr-style: signage, plates, sun
angle, vegetation.

## Misc binaries

`.pyc` → `pycdc`. Java class → `cfr`. Wasm → `wasm2wat`. Firmware → `binwalk -e`, then `firmwalker`.

## Deliverable

The flag and the escaping command, verbatim. For a jail, note the filter and the exact bypass that
defeated it.
