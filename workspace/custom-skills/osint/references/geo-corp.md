# Geolocation and corporate records

## Photo geolocation

Order: explicit text (signs, plates, shop names) → language and script → architecture → vegetation
and sky → sun angle.

- Signage: font, language, romanization. A dual-script sign narrows a country hard.
- Plates: shape, color, character set. `platesmania` and Wikipedia's plate pages.
- Road: markings, bollards, guardrail profile, direction of travel.
- Sun: shadow azimuth plus a date gives latitude. `suncalc` for the reverse.
- Utility: pole type, meter boxes, AC orientation.

Confirm with a Street View match from the same angle. "Looks like" is not a coordinate; give the
plus code and the two features that pin it.

## Corporate registries

| Jurisdiction | Registry |
| --- | --- |
| Netherlands | KVK |
| UK | Companies House (free API) |
| US | state Secretary of State, Delaware division |
| Indonesia | AHU (Kemenkumham), OSS |
| EU-wide | BRIS, VIES for VAT validity |

Pull: incorporation date, directors, registered agent, share capital, filings. Directors repeat across
companies — that is the graph edge.

VAT/VIES checks confirm a company exists for tax purposes; they do not confirm it is reputable.

## People

Email pattern inference: `first.last`, `f.last`, `first`. Verify with an SMTP `RCPT` probe where
allowed, or a `holehe` hit on a service that echoes the address.

Role changes over time show up in press releases and archived team pages. Save the archive URL.

## Ownership

Follow the chain to a natural person or a state entity. Bearer-share jurisdictions and nominee
directors dead-end; say so instead of guessing. Sanctions screening: EU consolidated list, OFAC SDN,
UN list — check the person and the entity.

## Traps

- Registered address is the accountant's office, not the operation.
- A shell company's director may be a nominee with 200 other appointments.
- Translated names: keep the local-script original next to the transliteration.
