
# Firmware Security Testing

OWASP FSTM, 9 stages. Use for embedded/IoT/router targets and bug bounty programs that include firmware.

## When to use
- Target is an IoT/embedded/router/camera/NAS device.
- You have (or can obtain) a firmware image (`.bin`, `.img`, `.trx`, OTA zip).
- You want to go from image → extracted filesystem → creds/backdoors → emulation → exploit.

## The 9 stages

### 1. Information gathering / recon (OSINT)
Collect before touching the device: CPU arch, OS platform, bootloader, hardware schematics, datasheets, LoC, source repo, third-party components, licenses, changelogs, **FCC ID**, data-flow diagrams, previous pentest reports, bug tracker / bug bounty presence.
- FCC ID → internal photos + test reports (often reveal chipset/UART pins).

### 2. Obtaining firmware
- Vendor support site / direct from dev team / build from source.
- **Google dorks**: `filetype:bin`, `filetype:img`, plus Dropbox/Drive links from forum threads.
- **Exposed cloud storage**: open S3 buckets.
- **MITM the update process** (device ↔ update server) → capture the firmware.
- **Hardware**: UART / JTAG / SPI flash dump (last resort: desolder flash chip).
- **Bootloader**: dump over tftp from U-Boot.
- Prefer a **debug build** if you can get it.

### 3. Analyzing firmware
```bash
file <bin>
strings -n5 <bin> | less
binwalk <bin>
hexdump -C -n 512 <bin> > hexdump.out
binwalk -E <bin>          # entropy — low = plaintext, high = encrypted/compressed
```
If nothing parses: it may be bare-metal, RTOS with custom FS, or **encrypted**. Binvis for visual entropy.

### 4. Extracting the filesystem
```bash
binwalk -ev <bin>          # -> _<bin>.extracted/
# squashfs / jffs2 / ubifs / cpio; unsquashfs, jefferson, ubireader
```
Tools: `binwalk`, `unsquashfs`, `jefferson` (jffs2), `ubireader`, `firmware-mod-kit`.

### 5. Analyzing filesystem contents
```bash
firmwalker _<bin>.extracted/       # greps for creds, certs, scripts, binaries
```
- Hardcoded credentials, private keys, API keys, backdoor accounts, `/etc/shadow`, `passwd`, `*.conf`.
- Init scripts / startup services → attack surface.
- **FACT** (Firmware Analysis Comparison Toolkit) for batch + CVE matching.
- Look for: `telnetd`, `dropbear`, `httpd`, custom web apps, `nvram` handling, `upnp`.

### 6. Emulating firmware
- **Partial**: `qemu-user` (single binary) or `FirmAE` — emulate just the web service for testing.
- **Full**: QEMU system emulation of the whole image (kernel + rootfs).
- `firmadyne` / `FirmAE` automate the common cases.

### 7. Dynamic analysis
- **Embedded web app testing** — proxy traffic through Burp, hunt the same web bug classes (command injection is extremely common in `httpd` CGIs).
- **Bootloader testing** — interrupt U-Boot, check for unlocked console / tftp.
- **Firmware integrity testing** — is the update signed? Can you flash a modified image?

### 8. Runtime analysis
- Attach `gdb`, `strace`, `ltrace` to the running service.
- Monitor processes, files, network.

### 9. Binary exploitation
- Find a buffer overflow in a network-facing binary → control flow → shell.
- Check for missing mitigations: `checksec`, NX, PIE, canary, RELRO.
- Arch matters — MIPS/ARM often no ASLR/NX → easy ROP.
- Common: command injection in CGI (shell metachar in a param), auth bypass in `httpd`.

## The script
`scripts/fw-recon.sh` runs stages 3–5 statically on a firmware image — file type, entropy, binwalk extraction, strings sweep for creds/keys, and an extracted-rootfs secret scan.
```bash
chmod +x scripts/fw-recon.sh
./scripts/fw-recon.sh firmware.bin
```
Requires `binwalk` (+ `sasquatch`/`unsquashfs`) and optionally `firmwalker`. It degrades gracefully if a tool is missing.

## Tool index
| Stage | Tools |
|-------|-------|
| Analyze | `binwalk`, `file`, `strings`, `hexdump`, `binvis` |
| Extract | `binwalk -ev`, `unsquashfs`, `jefferson`, `ubireader`, `firmware-mod-kit` |
| Contents | `firmwalker`, `FACT` |
| Emulate | `FirmAE`, `firmadyne`, `qemu-user`, `qemu-system` |
| Dynamic | Burp, `gdb`, `strace`, `ltrace`, `tcpdump` |
| Exploit | `checksec`, `pwntools`, `ropper`, `radare2`/`ghidra` |

## Pitfalls
- **binwalk install**: `pip install binwalk` is BROKEN — installs the package but `binwalk.core` is missing, so every invocation dies with `ModuleNotFoundError: No module named 'binwalk.core'`. Use `sudo apt-get install -y binwalk` instead (v2.3.4, works). Rust `binwalk` v3 (cargo) only if you need the newer engine.
- **fw-recon.sh path bug (fixed)**: the script `cd`s into its workdir, so the image arg must be `realpath`-resolved first or binwalk fails with "Cannot open file". Already patched in the script.
- Encrypted firmware — entropy check first, don't waste time binwalking an encrypted blob.
- Extraction tools fail on non-standard squashfs — try `sasquatch` (patched unsquashfs) before giving up.
- Emulation often needs `nvram` files and `/dev` stubs — FirmAE handles most.
- Command injection in CGI is the #1 real firmware bug — always proxy the web UI.
- FCC ID lookup frequently reveals the exact chipset + UART pinout.

## Authorization
Only extract/emulate/flash devices you own or have written authorization for. Flashing a modified image bricks devices — do it on your own hardware.
