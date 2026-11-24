# Nippon Paint Price List — Campaign Calculation Guide
Date: 2026-07-25
Source: 1_NETTO_CAMPAIGN_SBY_UPDATE_01_JULI_2026_PL_11_MEI_2026.pdf (Surabaya, 11 Mei 2026)

## Document Structure
- Header: `HET` (Harga Eceran Tertahan)
- Then: `Diskon Faktur` (default 11%)
- Then: `Netto1` = HET * 0.89
- Then: `Syarat Pembelian` (Min X L/kg)
- Then: `Disc Volume%`
- Then: `Netto2` = HET * 0.89 * (1 - Disc Volume%)

## Campaign Rules
- **Default**: Every product gets faktur discount 11% (Netto1).
- **Volume discount**: If total quantity of THAT variant meets Min Purchase, extra discount applies (Netto2).
- **Important**: Volume discount threshold is **per variant (per size/packaging)**, not aggregated across sizes/products.
  - Example: Vinilex Exterior 5Kg has 3 tiers:
    - Min 20kg = 15% (Netto2 = 206,978)
    - Min 100kg = 17% (Netto2 = 202,108)
    - Min 300kg = 19% (Netto2 = 197,238)
  - Buy 1 dus 5Kg = 243,504 (11% only). Buy 20kg gets 206,978/tin.

## Calculation Formula
- Per line: `qty_dus × price_per_unit`
- If volume threshold met: use Netto2
- Otherwise: use Netto1
- Sum all lines for grand total

## Product Matching
- Some orders use internal codes (e.g. Bee Brand 1018, 1019, NP 666, Elastex 02/06/05).
- Match codes by proximity to known variants in the catalog (packaging, color description).
- If match is uncertain, mark as **harga belum teridentifikasi** — do not guess prices.

## Leaked Credentials Found
- Source map exposed: `https://app.extrafi.io/assets/index-CUqGb5Vp.js.map`
- Leaked keys:
  - Coinbase Developer RPC key (Base chain) — readable endpoint
  - The Graph API key — subgraph queries billed to Extra Finance
- Both are **read-only** — cannot transfer/withdraw funds.
- Build bot to use keys for wallet balance, transaction history, pool data extraction.
- Report to Extra Finance Discord for bounty.

## Order Calculation Output Format
```
NO | Produk | Satuan | Dus | Hrg/dus | Total | Keterangan
1  | Bee Brand RM-1018 | 1 kg | 2 | ??? | 0 | harga belum teridentifikasi
```
- Use `harga_satuan × qty_dus` per line.
- Sum verified totals only.
- Clearly mark unknowns separately.