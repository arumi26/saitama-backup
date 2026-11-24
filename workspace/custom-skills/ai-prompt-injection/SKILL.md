
# AI Prompt Injection — Class Playbook

Testing AI/LLM applications for **prompt injection** and **guardrail bypass**. This is the umbrella for the *indirect* family (payload arrives inside data the model ingests), which is where the interesting, unpatched, high-value bugs live. Direct jailbreaks (user types the payload) are covered by `godmode`.

## When to Use

Trigger when the target is, or contains, an LLM/AI component that processes attacker-influenced content:

- Chatbot / assistant with RAG or file upload ("chat with your PDF", "analyze this doc")
- Resume / CV / invoice / receipt parser, KYC document pipeline
- AI email or attachment reader, AI summarizer, AI browser agent
- Agent with tools (code exec, HTTP fetch, file read) — injection → tool abuse
- Any pipeline with a **moderation/guardrail model** in front of a **generation model**

Also use when the user drops an offensive-security tool repo (e.g. a steganography/injection generator) and wants it unpacked, verified, and turned into a payload.

## Core Model: Direct vs Indirect

| Class | Who supplies the payload | Typical delivery | Notes |
|:------|:------------------------|:-----------------|:------|
| **Direct** | The user, in the chat box | typed prompt / API field | = jailbreak. See `godmode`. Heavily patched. |
| **Indirect** | A third party, via content the model later reads | uploaded doc, web page, email, RAG chunk, tool output, image | **Higher bounty value.** The user is a *carrier*, not the attacker. |

Indirect injection is the prize because the victim never sees the payload — it rides in a document, a scraped page, or an attachment.

## The Two-Parser Problem (the key insight)

Every AI document pipeline has **two independent readers of the same file**:

1. **Rendered layer** — what a human (or a vision model, or an OCR step) *sees*: glyphs, layout, colors, images.
2. **Extracted layer** — what a machine *reads*: raw Unicode from `document.xml`, `pdftotext` output, HTML source text, DOM text nodes.

**The gap between these two layers is the attack surface.** If you can make them disagree, you can show a benign-looking document to a reviewer/guardrail while the model ingests your actual instruction. Two classic consumers:

- **Security-AI** (guardrail) that scans *rendered* content or is shown a screenshot → sees the innocent version.
- **Human-AI** (the downstream assistant) that parses *extracted* text → gets the payload.

Same file. Two truths. See `references/evilfonttool-font-steganography.md` for a worked, verified example.

## Document-Deception Vectors

| Vector | Mechanism | Blocker it defeats |
|:-------|:----------|:-------------------|
| **Font steganography** | Custom font families where each glyph *renders* as one char but *encodes* a different Unicode codepoint. Human reads A, copy-paste/parser reads B. | Rendered-text review, screenshot guardrails |
| **Hidden text** | White-on-white, 0–1pt font, off-page/negative-margin text, `display:none`, collapsed table rows | Visual review (but NOT `pdftotext`/DOM extraction) |
| **Zero-width / ASCII smuggling** | Invisible Unicode (U+200B, U+FEFF) or Unicode Tags block smuggling a hidden string | Tokenizer-level filters; renders as nothing |
| **Image-embedded text** | Payload drawn as pixels; only the vision/OCR step reads it | Text-only scanners see no text at all |
| **Metadata injection** | `docx` comments, custom properties, `alt` text, EXIF, PDF annotations | Readers that only check the body |
| **Homoglyph swap** | Cyrillic/Greek lookalikes for trigger words | Keyword classifiers (weaker models only) |

Combine vectors: hidden text for the *instruction*, font steganography for the *cover story*, image text for the payload the vision model must read.

## Verification Methodology (do NOT skip)

Never claim a deception works without proving **both** layers from the actual artifact. This is the discipline that separates a real finding from a theory.

1. **Prove the rendered layer** — render to PNG, then OCR it:
   - HTML → headless Chromium screenshot
   - DOCX → LibreOffice/Word to PDF → `pdftoppm` → PNG
   - PDF → `pdftoppm` → PNG
   - Then `tesseract img.png -` and read what comes out.
2. **Prove the extracted layer** — pull the raw text the machine sees:
   - DOCX → `unzip` → `word/document.xml` → strip tags / read `<w:t>` runs
   - PDF → `pdftotext file.pdf -`
   - HTML → strip tags, or read the source text nodes
3. **Show they differ.** Two different strings from one file = verified. That's the deliverable.

Run `scripts/verify-visual-deception.sh <file>` to automate the render→OCR→extract comparison.

### Hard-won pitfalls (render step)

- **Headless screenshots come out BLANK if you don't wait for webfonts.** `--screenshot` fires before `@font-face` loads. Add `--virtual-time-budget=8000 --run-all-compositor-stages-before-draw` (or `--headless=new`). Symptom: PNG is all-white, OCR returns nothing.
- **Snap-packaged Chromium can't see `/tmp`** (confinement). If `--screenshot=/tmp/x.png` "writes" but the file is missing, write to `$HOME` instead.
- **Verify the PNG is not blank before OCR** — count non-white pixels with PIL. A 0-ink image means the render failed, not that the document is empty.
- **OCR quality ≠ deception strength.** tesseract reading the "human" text proves the *rendered glyphs* are legible; the deception is proven by that text differing from the extracted text.

## Building a Payload

1. **Recon the pipeline** — what does the guardrail see? A screenshot, the extracted text, or both? What does the downstream model see?
2. **Pick the gap** — if guardrail reads extracted text but user reads rendered → hide the payload in *rendered-only* (image/vision) space. If guardrail reads rendered/screenshot but model reads extracted → hide it in *extracted-only* (font stego, hidden text, zero-width) space.
3. **Split the payload** — cover story in one layer, instruction in the other.
4. **Test the guardrail in isolation** — feed it the file, confirm it passes.
5. **Test the model in isolation** — feed it the same file, confirm the instruction fires.
6. **Chain to impact** — injection alone is low. Escalate: data exfil (leak the system prompt / RAG corpus / other users' docs), tool abuse (fetch an attacker URL, run code), or ATO via the agent's actions.

## Pitfalls

1. **Injection alone is not a finding.** A model that says something weird = informational. Prove *impact*: exfil, tool execution, cross-tenant data, or guardrail bypass with a named consequence.
2. **Some backends are auth-gated.** A live demo's API can be an AWS Lambda Function URL with `AuthType=AWS_IAM` → every anonymous request is `403 AccessDeniedException`. That's not a bug, just inaccessible. Verify from both `curl` *and* a real browser context before concluding.
3. **Don't inflate severity.** Document deception is **low–medium** on its own. It's *trending* (AI-agent security is hot), which raises its *report acceptance*, not its CVSS.
4. **Copy-paste is the cheapest PoC.** `Ctrl+A`/`Ctrl+C` in a browser and paste into a plain text field is often the simplest demonstration that the extracted layer differs — no tooling required.
5. **Render ≠ extract for a reason.** Don't assume a vector works because it *should*; the renderer or parser may normalize it away. Always run step 1–3 above.

## Support Files

- `references/evilfonttool-font-steganography.md` — full breakdown of DoctorEww/EvilFontTool: the 96-font scheme, all four subcommands, verified human-vs-machine output, the "Flags for Sale" labs, and the AWS Lambda 403 finding.
- `scripts/verify-visual-deception.sh` — render + OCR + raw-extract a document and print the two layers side by side.
