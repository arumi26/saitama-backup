# CTF Forensics & Stego

**Load when:** CTF forensics, stego, steganography, pcap, memory dump, volatility, binwalk, carving, exiftool, zsteg, steghide, file identification, USB keystroke, DNS exfil, dispatched by ctf-whitehat-toolkit-2 forensics
# ⚠️ DISPATCHED by ctf-whitehat-toolkit-2 (CTF/Whitehat) — this file kept for detailed playbooks only

---

## SCOPE (baca dulu)
Sub-skill **forensics/stego** buat CTF in-scope, juga **fallback identifikasi file** kalau ctf-whitehat-toolkit-2 gak bisa kategorisasi. Setelah ctf-whitehat-toolkit-2 + scope check. Run tool di Docker sandbox.

## TOOLBOX (di sandbox)
binwalk/foremost (carving) · volatility3 (memory) · tshark/wireshark (pcap) · exiftool (metadata) · steghide/zsteg/stegseek/stegsolve (stego) · strings/xxd/file/hexedit

## STEP 0 — IDENTIFY (juga fallback ctf-whitehat-toolkit-2)
```bash
file artifact.*
xxd artifact.* | head
binwalk artifact.*          # appended/embedded data = trik PALING umum
strings -n 8 artifact.* | grep -iE "flag|password|secret"
```
Magic-byte mismatch (mis. `.png` yang aslinya zip) = klasik — fix header / carve.

## CARVING / ARCHIVES
```bash
binwalk -e artifact.bin              # auto-extract
foremost -i artifact.bin -o out/
binwalk artifact.png && dd if=artifact.png of=hidden.zip bs=1 skip=<offset>
zip2john secret.zip > h && john h --wordlist=rockyou.txt   # brute zip pw
```

## IMAGES / STEGO
```bash
exiftool image.jpg                   # metadata, GPS, comment
zsteg -a image.png                   # LSB PNG/BMP
steghide extract -sf image.jpg       # passphrase (coba kosong, lalu crack)
stegseek image.jpg rockyou.txt       # fast steghide crack
```
Audio: spectrogram (Sonic Visualiser/Audacity), LSB WAV samples.

## MEMORY (volatility3)
```bash
vol -f mem.raw windows.info
vol -f mem.raw windows.pslist
vol -f mem.raw windows.cmdline
vol -f mem.raw windows.filescan | grep -i flag
```
Juga: hashdump, netscan, clipboard, consoles.

## PCAP
```bash
tshark -r cap.pcap -q -z io,phs            # protocol hierarchy
tshark -r cap.pcap -Y http.request
tshark -r cap.pcap --export-objects http,out/
```
Shape umum: **USB HID** (decode keystroke pakai usbkbd map), **DNS/ICMP exfil** (reassemble subdomain/payload urut), FTP creds.

## DISK IMAGES
`mount -o ro,loop` → `find / -newer`, recover deleted (`testdisk`/`photorec`), slack space, ADS.

## SCOPE & DELEGATION
| Butuh | ctf-forensics-stego-2 | Delegasi |
|---|---|---|
| Target authorized | — | ctf-whitehat-toolkit-2 + `scope_guard.py` |
| Decode/crypto isi file | — | ctf-whitehat-toolkit-2 `ctf.py` / ctf-cryptography-2 |
| Validasi flag | — | `tools/ctf/flag_validator.py` |
| Full-auto swarm | — | `tools/ctf/run.py` |

## SAFETY RAILS
Flag lewat `flag_validator.py` → balik ctf-whitehat-toolkit-2 → HITL. Jangan invent. Jangan lecehkan data sensitif yang kebuka.

🔧 Upgrade: simpan artifact carved + offset di `work/<chal>/findings.json`.
