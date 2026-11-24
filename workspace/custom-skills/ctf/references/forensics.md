# forensics

Timeline first. The answer in a forensic challenge is a timestamp, a stream, or a deleted byte.

## pcap

```bash
tshark -r cap.pcap -q -z io,phs
tshark -r cap.pcap -Y "http.request" -T fields -e http.host -e http.request.uri
tshark -r cap.pcap --export-objects http,out/
tshark -r cap.pcap -Y "dns.qry.name" -T fields -e dns.qry.name | sort -u
```

Follow a TCP stream: `tshark -r cap.pcap -z follow,tcp,ascii,0`. TLS: look for a keylog, or
`SSLKEYLOGFILE` export; otherwise x509 metadata and SNI only.

Look for: base64 in HTTP bodies, credentials in FTP/POP3/SMTP, exfil over DNS (long labels), ICMP
payloads, `PK` zip magic in a stream.

## Memory

```bash
vol -f mem.raw windows.info
vol -f mem.raw windows.pslist.PsList
vol -f mem.raw windows.netscan.NetScan
vol -f mem.raw windows.cmdline.CmdLine
vol -f mem.raw windows.dumpfiles --virtaddr 0x...
vol -f mem.raw windows.memmap.Memmap --pid 1234 --dump
```

`strings -el` for UTF-16, then grep for flags, URLs, and passwords near `CREDENTIAL`. Volatility 3
syntax; plugin names differ per profile.

## Disk

```bash
mmls disk.img; fls -r -p image.dd | less
icat image.dd <inode> > recovered.bin
tsk_recover image.dd out/
```

Deleted files, unallocated space (`blkls`), the MFT (`$MFT` parse), volume shadow copies, and
browser SQLite (`History`, `Cookies` — decrypt needs the DPAPI key from the user hive).

## Steganography

```bash
binwalk -e carrier.png; zsteg carrier.png; stegseek carrier.jpg rockyou.txt
exiftool carrier.jpg; strings -n 8 carrier.jpg | tail
```

Least-significant-bit planes: `zsteg -a`. Audio: `sonic-visualiser`, `ffmpeg -i a.wav -f s16le -`.
Appended data after EOF, chunk order anomalies, palette tricks.

## Documents

`oledump.py`, `pdf-parser.py`, `pdfid.py`, `msoffcrypto-tool`. Macros: `olevba`. A `.doc` that opens
a URL is a dropper; extract the URL before executing anything.

## Deliverable

A timeline (`csv` of time, source, artifact), the recovered object, and the flag. Every claim has a
byte offset or a packet number.
