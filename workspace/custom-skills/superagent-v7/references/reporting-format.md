# Reporting format & disclosure preferences (2026-07-20 session)

Use this when drafting submissions for Nanwasa.

## Hard rules
- **Language:** English for every external/bug bounty submission.
- **Combine related findings:** If he finds 2+ bugs in one protocol/repo, merge them into a single report/message instead of sending separate emails.
- **Initial disclosure is minimal:** first contact should say only that a vulnerability was found and ask for a secure contact path. Do not include full technical details or exploit steps in the first message.

## First-message template
Subject: Security disclosure — <count> issue(s) in <protocol>
Body:
- Who you are / handle.
- Repo or affected URL.
- One-line per issue: name + severity.
- Request confirmation and preferred secure channel.
- Do not paste full impact chain, attack flow, or PoC yet.

## Follow-up / full disclosure
- Provide exact affected files + line ranges.
- Provide impact chain in plain English, no jargon overload.
- Provide fix recommendations as short checklist.
- If he asks for bug explanation in chat, use short Indonesian casual analogies; do not dump full markdown unless asked.

## Do not do
- Do not repeat the same report content in chat after sending; reference the file path only.
- Do not ask “should I send now?” after he already said to submit; just send and confirm.
- Do not send to low-signal channels if a direct contact exists; prefer direct email, then official disclosure channel, then Discord/Telegram.
