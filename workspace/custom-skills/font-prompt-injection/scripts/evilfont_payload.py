#!/usr/bin/env python3
"""
evilfont_payload.py — payload builder + verifier for EvilFontTool (font-based
prompt injection / dual-layer text deception).

Core idea
---------
A single document carries TWO different texts:
  * VISUAL layer  -> what a human / OCR / vision model reads (rendered glyphs)
  * TEXT layer    -> what a machine extracts (raw Unicode, copy-paste, DLP, an
                     LLM guardrail that scans extracted text)

`evilfonttool` builds the artifact. This wrapper removes the friction:
  * auto-pads cover lines to satisfy EvilFontTool's "computer line >= human line"
    length constraint (the #1 thing that breaks manual runs)
  * generates benign cover text with a trigger-word linter
  * supports BOTH directions (payload in visual layer, or payload in text layer)
  * ships a `verify` mode that extracts both layers and OCRs the render, so you
    can PROVE the deception works before shipping.

Requires: evilfonttool installed (`pip install -e .` in the repo) + a reference
.ttf + tesseract (for verify OCR) + chromium or any headless browser for verify.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import zipfile
from pathlib import Path

# ---------------------------------------------------------------------------
# Benign cover corpus — neutral, innocuous sentences with NO trigger words.
# Used to build the machine-visible layer so a guardrail sees nothing suspicious.
# ---------------------------------------------------------------------------
BENIGN_SENTENCES = [
    "Hello there nice weather we are having today.",
    "I hope you have a good day and a pleasant week ahead.",
    "The quarterly report is attached for your review.",
    "Please find the updated schedule for next month below.",
    "Thanks for your continued support on this project.",
    "The meeting notes from Tuesday are included here.",
    "Kind regards and best wishes for the upcoming holiday.",
    "Let me know if you need any further details about this.",
    "The attached file contains the usual weekly summary.",
    "We appreciate your patience while this is being processed.",
    "Everything looks good on our side for the handover.",
    "Please review the document at your earliest convenience.",
    "This note is just a friendly reminder about the deadline.",
    "The team has finished the initial draft for the proposal.",
    "Have a wonderful afternoon and enjoy the rest of the day.",
    "No action is required from you at this time.",
    "The presentation slides have been shared with the group.",
    "Looking forward to hearing your thoughts on the matter.",
]

# Words that commonly trip a security-AI / DLP / guardrail. If the COVER (machine
# layer) contains any, the deception is pointless — the guardrail fires anyway.
TRIGGER_WORDS = [
    "flag", "password", "passwd", "secret", "token", "apikey", "api key",
    "credential", "credentials", "private key", "seed phrase", "mnemonic",
    "ignore previous", "ignore all previous", "disregard", "system prompt",
    "reveal", "leak", "exfiltrate", "exfil", "override", "jailbreak",
    "developer mode", "sudo", "root access", "admin password", "ssh key",
    "confidential", "top secret", "internal only", "do not share",
]


def _log(msg: str) -> None:
    print(f"[evilfont] {msg}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Layer construction
# ---------------------------------------------------------------------------
def _read_lines(arg: str) -> list[str]:
    """Read payload/cover from a literal string, a file, or stdin ('-')."""
    if arg == "-":
        return sys.stdin.read().splitlines()
    p = Path(arg)
    if p.is_file():
        return p.read_text(encoding="utf-8").splitlines()
    return arg.split("\\n")


def _cover_for_length(target_len: int, rng: list[str]) -> str:
    """Build a benign sentence >= target_len chars, cycling the corpus."""
    out = ""
    i = 0
    while len(out) < target_len:
        piece = rng[i % len(rng)]
        out = (out + " " + piece).strip() if out else piece
        i += 1
        if i > 10000:  # safety
            break
    return out


def build_cover(payload_lines: list[str], corpus: list[str] | None = None) -> list[str]:
    """Produce cover lines, one per payload line, each >= its payload length."""
    corpus = corpus or BENIGN_SENTENCES
    cover = []
    for idx, pl in enumerate(payload_lines):
        # rotate the corpus per line so consecutive lines differ
        rotated = corpus[idx % len(corpus):] + corpus[:idx % len(corpus)]
        cover.append(_cover_for_length(max(len(pl), 1), rotated))
    return cover


def lint(cover_lines: list[str]) -> list[tuple[int, str]]:
    """Return [(line_no, trigger_word)] hits in the machine-visible layer."""
    hits = []
    for i, line in enumerate(cover_lines, 1):
        low = line.lower()
        for w in TRIGGER_WORDS:
            if w in low:
                hits.append((i, w))
    return hits


def pad_to(lines: list[str], widths: list[int]) -> list[str]:
    """Pad each line with benign trailing spaces so len >= width (EvilFont needs
    computer >= human). Trailing spaces are invisible in most renderers."""
    out = []
    for ln, w in zip(lines, widths):
        out.append(ln + " " * max(0, w - len(ln)))
    return out


# ---------------------------------------------------------------------------
# evilfonttool orchestration
# ---------------------------------------------------------------------------
def _run(cmd: list[str]) -> None:
    _log("$ " + " ".join(cmd))
    subprocess.run(cmd, check=True)


def ensure_fonts(ref_font: str, workdir: Path, font_name: str) -> Path:
    """Create the evil fonts if not already present. Returns the ttf dir."""
    ttf_dir = workdir / "ttffonts"
    if ttf_dir.is_dir() and any(ttf_dir.glob("*.ttf")):
        _log(f"reusing fonts in {ttf_dir}")
        return ttf_dir
    if not ref_font or not Path(ref_font).is_file():
        sys.exit(f"reference font not found: {ref_font!r} (pass --ref-font)")
    _run(["evilfonttool", "create", ref_font, str(workdir), font_name])
    return ttf_dir


def cmd_build(a: argparse.Namespace) -> int:
    workdir = Path(a.workdir).resolve()
    workdir.mkdir(parents=True, exist_ok=True)

    payload = _read_lines(a.payload)
    if not payload or all(not x.strip() for x in payload):
        sys.exit("empty payload")

    # Direction: which layer carries the payload?
    #   visual (default) -> human/OCR sees payload, machine sees benign cover
    #   text  (--reverse)-> machine sees payload, human/OCR sees benign cover
    if a.reverse:
        text_lines = payload
        visual_lines = (
            _read_lines(a.cover) if a.cover else build_cover(payload, None)
        )
        # constraint: text(computer) line >= visual(human) line
        text_lines = pad_to(text_lines, [len(v) for v in visual_lines])
        human_lines, computer_lines = visual_lines, text_lines
        _log("mode=REVERSE  (payload in TEXT layer, benign in VISUAL layer)")
    else:
        visual_lines = payload
        text_lines = (
            _read_lines(a.cover) if a.cover else build_cover(payload, None)
        )
        text_lines = pad_to(text_lines, [len(v) for v in visual_lines])
        human_lines, computer_lines = visual_lines, text_lines
        _log("mode=VISUAL  (payload in VISUAL layer, benign in TEXT layer)")

    # Lint the machine-visible layer (the one a guardrail reads)
    machine_layer = computer_lines if not a.reverse else computer_lines
    hits = lint(machine_layer)
    if hits and not a.force:
        _log("WARNING: trigger words found in the MACHINE-visible layer:")
        for ln, w in hits:
            _log(f"  line {ln}: {w!r}")
        _log("  -> the guardrail may fire anyway. Fix cover text or pass --force.")

    hf = workdir / "human.txt"
    cf = workdir / "computer.txt"
    hf.write_text("\n".join(human_lines) + "\n", encoding="utf-8")
    cf.write_text("\n".join(computer_lines) + "\n", encoding="utf-8")
    _log(f"wrote {hf} and {cf}")

    fmt = a.format
    preview = None
    if fmt in ("docx", "pdf"):
        ensure_fonts(a.ref_font, workdir, a.font_name)
        out = Path(a.out) if a.out else workdir / "payload.docx"
        _run(["evilfonttool", "doc", str(hf), str(cf), str(out), a.font_name,
              "--ttf-dir", str(workdir / "ttffonts")])
        if fmt == "pdf":
            pdf = out.with_suffix(".pdf")
            _run(["evilfonttool", "pdf", str(out), str(pdf),
                  "--ttf-dir", str(workdir / "ttffonts")])
            out = pdf
        # emit an HTML preview inside the workdir (fonts.css + fonts/ are there)
        # so `verify` can OCR the visual layer — a .docx/.pdf can't be
        # screenshotted without LibreOffice.
        preview = workdir / "preview.html"
        cwd = os.getcwd()
        os.chdir(workdir)
        try:
            _run(["evilfonttool", "web", str(hf), str(cf), str(preview)])
        finally:
            os.chdir(cwd)
    else:  # html
        # evilfonttool web needs fonts.css in the cwd of the output
        if not (workdir / "fonts.css").exists():
            ensure_fonts(a.ref_font, workdir, a.font_name)
        out = Path(a.out) if a.out else workdir / "payload.html"
        cwd = os.getcwd()
        os.chdir(workdir)
        try:
            _run(["evilfonttool", "web", str(hf), str(cf), str(out)])
        finally:
            os.chdir(cwd)

    _log(f"BUILT {out}")
    if preview:
        _log(f"preview -> {preview}")
        # sidecar pointer so `verify` never has to guess which preview belongs
        # to this artifact (multiple builds in one dir would otherwise collide)
        try:
            Path(str(out) + ".preview").write_text(str(preview), encoding="utf-8")
        except OSError:
            pass
    print(str(out))
    return 0


# ---------------------------------------------------------------------------
# Verifier — prove the two layers actually differ
# ---------------------------------------------------------------------------
def _docx_text(path: Path) -> str:
    with zipfile.ZipFile(path) as z:
        xml = z.read("word/document.xml").decode("utf-8", "replace")
    # crude but faithful: concatenate <w:t> runs
    runs = re.findall(r"<w:t[^>]*>(.*?)</w:t>", xml, re.S)
    return "".join(runs)


def _html_text(path: Path) -> str:
    html = path.read_text(encoding="utf-8", errors="replace")
    # strip tags; keep entity-decoded text
    import html as _h
    body = re.sub(r"<script.*?</script>", "", html, flags=re.S)
    body = re.sub(r"<style.*?</style>", "", body, flags=re.S)
    body = re.sub(r"<[^>]+>", "", body)
    return _h.unescape(body)


def _ocr(path: Path, png: Path) -> str:
    if not shutil.which("tesseract"):
        return "<tesseract not installed>"
    browser = next((b for b in ("/usr/bin/chromium-browser", "chromium-browser",
                                "chromium", "google-chrome", "google-chrome-stable")
                    if shutil.which(b) or Path(b).exists()), None)
    if not browser:
        return "<no headless browser found>"
    # IMPORTANT: snap-confined chromium can neither READ a file:// URL under /tmp
    # nor write a screenshot there (private /tmp namespace), AND its `home`
    # interface blocks hidden dirs (~/.cache). So we stage a copy of the render
    # target's directory in a NON-HIDDEN dir under $HOME and render from there.
    src_dir = path.resolve().parent
    stage = Path.home() / "evilfont-render"
    if stage.exists():
        shutil.rmtree(stage, ignore_errors=True)
    stage.mkdir(parents=True, exist_ok=True)
    try:
        shutil.copytree(src_dir, stage, dirs_exist_ok=True)
    except OSError as e:
        return f"<stage copy failed: {e}>"
    staged_html = stage / path.name
    png = (stage / (Path(png).stem + ".png")).resolve()
    try:
        subprocess.run(
            [browser, "--headless=new", "--no-sandbox", "--disable-gpu",
             "--hide-scrollbars", "--allow-file-access-from-files",
             "--force-device-scale-factor=2", "--virtual-time-budget=8000",
             "--run-all-compositor-stages-before-draw",
             f"--screenshot={png}", staged_html.as_uri()],
            capture_output=True, timeout=90,
        )
    except subprocess.TimeoutExpired:
        return "<screenshot timed out>"
    if not png.exists():
        return "<screenshot failed>"
    r = subprocess.run(["tesseract", str(png), "-"], capture_output=True, text=True)
    return r.stdout.strip()


def cmd_verify(a: argparse.Namespace) -> int:
    p = Path(a.file).resolve()
    if not p.exists():
        sys.exit(f"not found: {p}")
    if p.suffix == ".docx":
        text_layer = _docx_text(p)
    elif p.suffix in (".html", ".htm"):
        text_layer = _html_text(p)
    else:
        sys.exit("verify supports .docx / .html")

    print("=" * 68)
    print("TEXT LAYER  (what a machine / DLP / guardrail extracts)")
    print("=" * 68)
    print(text_layer.strip())
    print()
    if a.no_ocr:
        return 0

    # For a .docx/.pdf we OCR an HTML preview (a document can't be screenshotted
    # without LibreOffice). Prefer the sidecar pointer written by `build`; fall
    # back to --preview, then to common locations.
    render_target = p
    if p.suffix in (".docx", ".pdf"):
        sidecar = Path(str(p) + ".preview")
        cands = []
        if sidecar.is_file():
            cands.append(Path(sidecar.read_text(encoding="utf-8").strip()))
        if a.preview:
            cands.append(Path(a.preview))
        cands += [p.with_name("preview.html"), p.with_suffix(".preview.html")]
        render_target = next((c for c in cands if c.is_file()), None)
        if render_target is None:
            sys.exit("no HTML preview found; re-run build, or pass --preview <html>")

    print("=" * 68)
    print("VISUAL LAYER  (what a human / OCR / vision model reads)")
    print("=" * 68)
    png = p.with_suffix(".verify.png")
    ocr = _ocr(render_target, png)
    print(ocr)
    print()
    print("=" * 68)
    print("RESULT")
    print("=" * 68)
    tl = re.sub(r"\s+", " ", text_layer).strip()
    vl = re.sub(r"\s+", " ", ocr).strip()
    ocr_failed = ocr.strip().startswith("<") and ocr.strip().endswith(">")
    if ocr_failed or not vl:
        print("⚠️  could not compare — OCR/render unavailable (see VISUAL LAYER above).")
    elif not tl:
        print("⚠️  could not compare — text layer empty.")
    elif tl != vl:
        print("✅ DECEPTION ACTIVE — the two layers differ.")
    else:
        print("❌ layers identical — deception NOT working (fonts missing/not embedded?)")
    return 0


# ---------------------------------------------------------------------------
def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    b = sub.add_parser("build", help="build a dual-layer payload artifact")
    b.add_argument("--payload", required=True,
                   help="text the target layer should show (literal, file, or '-')")
    b.add_argument("--cover", help="benign text for the other layer (default: auto)")
    b.add_argument("--format", choices=["docx", "pdf", "html"], default="docx")
    b.add_argument("--out", help="output file path")
    b.add_argument("--workdir", default="./evilfont-work")
    b.add_argument("--ref-font",
                   default="/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf")
    b.add_argument("--font-name", default="Consolas")
    b.add_argument("--reverse", action="store_true",
                   help="payload goes in the TEXT layer instead of the VISUAL layer")
    b.add_argument("--force", action="store_true",
                   help="build even if the machine layer trips trigger words")
    b.set_defaults(func=cmd_build)

    v = sub.add_parser("verify", help="extract both layers and prove they differ")
    v.add_argument("file")
    v.add_argument("--no-ocr", action="store_true")
    v.add_argument("--preview", help="path to the HTML preview for a .docx/.pdf")
    v.set_defaults(func=cmd_verify)

    a = ap.parse_args()
    return a.func(a)


if __name__ == "__main__":
    sys.exit(main())
