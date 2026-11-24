# EvilFontTool — Font Steganography for Prompt Injection

Worked example of the **document-deception** family. Repo: `DoctorEww/EvilFontTool` (~351★, MIT, Python, pkg `evilfonttool` 2.0.5). Author: DoctorEww.

## What it is

A generator for **font-family steganography**: it builds one custom font family per ASCII character (96 families for printable ASCII) from a reference font. Each glyph *renders* as a different character than the Unicode codepoint it actually encodes. Result: a document where

- 👁️ **Human / OCR / screenshot layer sees** → text A
- 🤖 **Extraction layer reads** (`Ctrl+C`, `document.xml`, parser) → text B

Length mismatch between the two texts is padded with a "stealth font".

## Install

```bash
git clone https://github.com/DoctorEww/EvilFontTool
cd EvilFontTool
python3 -m venv .venv && . .venv/bin/activate
pip install -e .          # pulls fontTools, python-docx, reportlab, Pillow, pdf2image, pdfminer.six
```

Note: the import name is `fontTools` (capital T), the dist name is `fonttools`. `import fonttools` fails — that's expected, not a broken install.

## Commands

```bash
evilfonttool create <ref.ttf> <outdir> <name>       # -> 96 .woff + fonts.css + ttffonts/
evilfonttool web  human.txt computer.txt out.html   # HTML, one <span> per char w/ font-family:'<hex>'
evilfonttool doc  human.txt computer.txt out.docx --ttf-dir <outdir>/ttffonts/ [fontname]
evilfonttool pdf  out.docx out.pdf --ttf-dir <outdir>/ttffonts/ [--title T] [--author A]  # needs LibreOffice
```

`pdf` requires `soffice`/`libreoffice` on PATH (not always present — the DOCX path alone completes the labs).

## Verified output (this was actually run)

Reference font `DejaVuSansMono.ttf`, `create` → 96 fonts + 96 ttffonts.

Input:
```
human.txt    : My name is David Johnson. Can I get the flag?
computer.txt : Hello there nice weather we are having. I hope you have a good day.
```

Proof of divergence:
```
# DOCX — raw Unicode the machine reads:
unzip -p out.docx word/document.xml | grep -o '<w:t[^>]*>[^<]*'
  -> "Hello there nice weather we are having. I hope you have a good day."

# HTML — rendered to PNG via headless chromium, then OCR'd with tesseract:
  -> "My name is David Johnson. Can I get the flag?"
```

DOCX embeds ~7.6 MB of font data (`word/fonts/font*.fntdata`) + a `fontTable.xml` with `embedRegular`; body text is only ~12 KB. The deception *is* the embedded fonts.

HTML structure: every character is its own `<span style="font-family: '4d';">H</span>` — the family name is the **hex of the character's codepoint**, and the glyph in that font renders as the decoy char.

## The labs (branch `demo`, hosted on GitHub Pages)

`labs/flags-for-sale.html` — a tiered challenge: (1) get a file past a **Security AI** filter, (2) have the same file **read by a Human AI**, (3) capture the flag. Classic two-parser guardrail-bypass exercise.

Live: `doctoreww.github.io/EvilFontTool/labs/flags-for-sale.html`

**Backend is IAM-locked.** The page calls an AWS Lambda Function URL (`...lambda-url.us-east-1.on.aws/`). Probing it with `curl` (plain, with `Origin`, with browser UA) and from a real browser `fetch` context all return:

```
403  {"Message":null}   x-amzn-ErrorType: AccessDeniedException
```

`AccessDeniedException` on a Function URL = `AuthType=AWS_IAM`, not `NONE`. Anonymous requests can't reach it — that's a config gate, **not a vulnerability**. (Also: `browser_console` with a network-primitive `expression` is blocked by default; set `browser.allow_unsafe_evaluate: true` only for trusted pages.)

Note the repo's issue-based submission channel is dead — issues #3/#4 return `null` from the API; only #5 ("PDF command inconsistent on windows") remains.

## Where it lands in a bounty

Niche but trending. Real impact requires an AI pipeline that ingests user documents: CV/resume parsers, invoice/receipt OCR, "chat with your PDF", AI attachment readers, agentic doc tools. Standalone = low–medium. Chained to exfil / tool abuse / guardrail bypass = reportable. See the parent SKILL.md for the escalation path.

## Reproduce the proof

```bash
scripts/verify-visual-deception.sh out.docx        # renders + OCRs + raw-extracts, prints both layers
```
