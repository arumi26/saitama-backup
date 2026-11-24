# Multi-X

X bans for burst, not for volume. The pool exists to look like separate humans, so keep the
behavior separate.

## Session material

Per account, from a logged-in browser:

- `auth_token` — the `auth_token` cookie
- `ct0` — the `ct0` cookie (also the CSRF header value)

DevTools → Application → Cookies → `https://x.com` → copy both. They last months; a password change
or a "log out of all devices" invalidates them.

```bash
python -m muse x add @handle <auth_token> <ct0> --proxy socks5h://127.0.0.1:1080
python -m muse x check
```

One proxy per account after the first three. Sticky residential or mobile; datacenter IPs get
challenged faster.

## Pacing

Defaults: 3–9 s randomized gap, 40 follows/account/day, ~120 likes/account/day, replies 1 per
10 minutes per account. Hot accounts (young, low followers) get half.

The driver turns a `429` into a cooldown from `x-rate-limit-reset` and routes to another account
instead of sleeping the run.

## Run order

1. `x check` — every account must verify.
2. `x follow --file targets.txt --dry-run` — read the plan.
3. `x follow --file targets.txt --cap 40` — real run.
4. Wait a day. Follow-backs need time before a like pass is worth it.
5. `x like @target --count 3 --keyword <topic>` — engaged audience only.
6. `x comment @target --count 2` — replies on fresh tweets, template rotated.

## Target selection

Follow the followers of adjacent accounts, not the accounts themselves. A target list scraped from
one big account is a fingerprint; mix three sources and shuffle.

Quality filter before the run: bio keyword match, ≥ 50 followers, posted in the last 30 days,
ratio above 0.3. Drop the obvious bots.

## Comments

Templates live in `config/x-templates.txt`, one per line, `{author}` substituted. Rules:

- reference something in the tweet, not the account
- 8–20 words, no emoji, no hashtag, no link
- one reply per account per target per day
- never reply twice to the same tweet from two accounts within an hour

A reply that could sit under any tweet is a wasted reply.

## Warm-up schedule (new account)

| Day | Follows | Likes | Replies |
| --- | --- | --- | --- |
| 1–2 | 10 | 20 | 2 |
| 3–5 | 20 | 40 | 5 |
| 6–10 | 30 | 70 | 8 |
| 11+ | 40 | 120 | 12 |

## Suspension hygiene

- Distinct UA per account (the driver sends one Chrome UA; vary it if you run many).
- Do not run two accounts from one IP within the same minute.
- Do not cross-follow the pool from itself in one burst.
- If an account gets a phone verification wall, park it for 48 h; do not retry the same action.
- Keep one account clean of automation entirely — it is the recovery account.

## Data

`state/actions.db` holds every action with a timestamp, deduped on `(action, account, target)`.
`python -m muse ledger` shows today's counts per type. Before a run, check the counts; a rerun
after a partial failure is safe because of the dedupe key.

## Limits worth knowing

- `friendships/create` — 400/day hard cap on old accounts, ~50/day safe on new.
- `favorites/create` — 1000/day hard, ~200 safe.
- `statuses/update` — 300/3h hard, replies count.
- Reads are cheap; the timeline call is the one to cache.

## Failure handling

`326` — account locked, needs a browser login. `32` — bad auth, re-copy the cookies. `88` — rate
limit, the driver handles it. `187` — duplicate status, the reply text repeated within 24 h.
`261` — write restricted, park the account.
