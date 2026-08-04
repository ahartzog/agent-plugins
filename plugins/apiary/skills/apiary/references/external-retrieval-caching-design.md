# External Retrieval Caching — Design

A proposal, not yet implemented protocol. Companion to `references/external-retrieval-design.md`
and `protocol/routing-protocol.md` (§Resolve, §Extract). Loaded on demand — when implementing the
read-time cache, or when asking why it works this way.

Resolves `BACKLOG.md` § External Retrieval → "Local cache for fetched external documents."

---

## The problem

§Resolve re-fetches on every Ask. A session opens a 4 MB `.xlsx` from SharePoint at 10am; a
different session that afternoon asks a question the same file answers, and pays auth, download,
and parse again. Nothing about the file changed. Nothing about the first fetch was kept.

This is distinct from the two surfaces that already exist:

- **`sources/`** is the *durable* fetch-once surface — committed, indexed, Sentinel-gated, permanent.
  It is the right home for material worth keeping (`protocol/sources-policy.md`).
- **The turn's context** is where fetched content lives today, and it dies with the session.

The gap is the middle: material referenced *incidentally* by a session, worth keeping for days, not
worth depositing forever. A one-off spreadsheet consulted to answer one question does not belong in
the Hive's permanent record — depositing it would violate Goal 1 as surely as pasting it into a
knowledge file. But re-downloading it every session is pure waste.

So: **a disposable, per-user, read-time cache that is not part of the Hive.**

---

## What the cache is not

| | Read-time cache | `sources/` |
|---|---|---|
| Lifetime | Days; evictable at any moment | Permanent |
| Committed to git | No | Yes |
| Indexed | No | Yes (`sources/index.md`) |
| Sentinel-scanned | No | Yes (text) |
| Discoverable by Ask | No — it is transparent, not addressable | Yes |
| Goal 9 applies | **No** | Yes |

The Goal 9 exemption is the load-bearing claim here, so it is stated rather than assumed.
Goal 9 requires every *content surface* to have an index, a write path, and an audit check. The
cache is not a content surface: it holds no content that is not already reachable at its canonical
URL, and deleting the entire cache changes no answer the Hive can give — only how fast it gives it.
`protocol/knowledge-schema.md` § Inline Annotations already establishes the category ("read-time
usage telemetry belongs in a disposable retrieval cache, not in knowledge content"); this design
extends the same category from telemetry to fetched bytes.

The practical consequence: **Audit must never be asked to index the cache**, and a cache miss is
never a defect. If either becomes tempting, the cache has grown into something that should have been
`sources/`.

---

## Cache root — where it lives, cross-OS

```
$CLAUDE_PLUGIN_DATA/retrieval-cache/<hive-slug>/<sha256(canonical_url)>/
    meta.json
    body.<ext>
```

`CLAUDE_PLUGIN_DATA` resolves to `~/.claude/plugins/data/<plugin>-<marketplace>/`. Claude Code owns
that resolution, which is why it is the right root: it is already correct on macOS, Linux, and
Windows without the protocol containing a single OS branch. Fallback when the variable is unset:
derive `~/.claude/plugins/data/apiary-<marketplace>/` and create it.

Rejected alternatives:

- **In-repo `.hive-cache/`, gitignored.** Puts fetched external content inside the Hive's
  protection boundary and one `git add -A` away from being committed. The repo is the artifact
  the Hive protects; the cache must sit outside it.
- **OS temp (`/tmp`, `%TEMP%`).** Wiped on schedules the protocol cannot predict — a cache that may
  vanish mid-session is a cache whose TTL means nothing. Also the one place where the path genuinely
  differs per OS.

**Partition by Hive slug, not globally by URL.** A global cache keyed only by URL would let a
document fetched by one Hive be served to another with a different protection posture. Sharing
across Hives is a marginal hit-rate gain for a real cross-boundary risk; the partition is cheap.

---

## Cache key — hash the canonical URL

The key is `sha256` of the canonicalized absolute URL, hex-encoded. Hashing is not for security; it
is for **filename safety across three filesystems at once**. A raw URL as a directory name collides
with all of: Windows reserved characters (`? : * | " < >`), Windows path-length limits, and the
case-sensitivity mismatch between APFS/NTFS (insensitive) and ext4 (sensitive). A hex digest is
valid, fixed-length, and case-stable everywhere. Human-readable identity goes in `meta.json`, where
it belongs.

**Canonicalization before hashing** (each rule prevents a real duplicate-download bug):

1. **Strip the fragment.** `#section-3` is an §Extract concern, not a fetch concern — the same
   download serves every section. Keying on the fragment would re-download the same file per anchor.
2. Lowercase the scheme and host; preserve path case (Linux servers are case-sensitive).
3. Drop known tracking/session params (`?web=1`, `&csf=`, `&e=`); preserve params that select
   content (a Confluence `pageId`, a Box `?version=`).
4. Resolve store-relative locators to absolute *first* (`routing-protocol.md` §Resolve), then
   canonicalize. Otherwise the same document caches twice — once per catalog row that names it.

Hashing command, in fallback order — the one place a cross-OS branch is unavoidable:
`sha256sum` (Linux, Git Bash) → `shasum -a 256` (macOS) → `openssl dgst -sha256`. Git Bash on
Windows carries `sha256sum`, so this chain covers all three platforms without invoking PowerShell.

---

## Freshness — TTL bounds disk, validators protect correctness

These are two mechanisms doing two different jobs, and conflating them is how this design fails.

- **TTL (default 7 days)** is a **disk-hygiene** policy. It bounds unbounded growth and guarantees
  nothing about correctness.
- **The validator check** is the **correctness** mechanism. It is what makes serving a cached byte
  defensible.

**A cache hit inside the TTL is not sufficient reason to serve.** Recording this explicitly because
the obvious future "optimization" — trust the TTL, skip the validator — silently reintroduces
exactly the failure `routing-protocol.md` exists to prevent: answering from a stale local copy while
staying quiet about it.

Resolution order for a locator with a cache entry present:

| State | Action |
|---|---|
| Absent | Fetch. Write body + `meta.json`. |
| Past TTL | Evict without validating. Fetch fresh. (Expiry is hygiene — do not spend a call to rescue a week-old entry.) |
| Within TTL, validator says **unchanged** | Serve from cache. **Silent** — no user-facing caveat needed; freshness was confirmed. |
| Within TTL, validator says **changed** | Re-fetch, overwrite, reset `fetched_at`. |
| Within TTL, validator **unavailable** | Serve from cache **with an explicit caveat** naming the fetch timestamp and why freshness could not be confirmed. |

The last row is the design's real decision. "Validator unavailable" is not rare — it is offline
work, an expired auth session, a store with no cheap metadata endpoint, or a web host that ignores
`If-None-Match`. Two ways to get it wrong: refuse to serve (the cache is useless exactly when it is
most valuable — degraded connectivity) or serve silently (the stale-summary failure). The honest
third path is to serve and disclose, which is the same explicit-degradation contract
`tool-tiers.md` § Degradation Patterns already applies to a missing tool:

> "Answering from a copy cached 2026-07-24; I could not confirm it is current — the SharePoint
> session is not authenticated. Re-run after `chrome-auth` login to verify."

Ordering follows the same logic as §Prefer: the validator call is cheap, the download is not, so pay
the cheap call to avoid the expensive one.

---

## Freshness signals belong in `tool-tiers.md`, as a column

Every store already has a cheap freshness signal; they are simply per-store mechanics:

| Store kind | Freshness signal |
|---|---|
| `confluence` | `version.number` |
| `sharepoint` | Graph `eTag` / `lastModifiedDateTime` |
| `box` | file info `etag` / `modified_at` |
| `quip` | thread `updated_usec` |
| `jira` | `fields.updated` |
| `ghe` / `gitlab` | last commit sha touching the path |
| `public-web` | `If-None-Match` / `If-Modified-Since` (frequently unsupported → unavailable path) |

**This table should not live in this file.** It should be a third column on
`tool-tiers.md` § Store Kind → Tool, for the reason `external-retrieval-design.md` already gives:
a new store kind must stay *one row of data*, not another prose case in a protocol file. Store kind,
the tool that reaches it, and the signal that dates it are the same shape of fact about the same
row. Reproduced here only to show the mechanism is real for every store the Apiary supports; the
implementing change moves it.

This inherits the open question in `BACKLOG.md` about re-homing `tool-tiers.md` as a resolver
registry — a third column makes that table more clearly org-wide reference data, which
strengthens the case rather than complicating it.

---

## `meta.json`

```json
{
  "canonical_url": "https://example.sharepoint.com/sites/…/Payload-ICD-revC.xlsx",
  "display_name": "Payload ICD rev C",
  "store_kind": "sharepoint",
  "body_file": "body.xlsx",
  "fetched_at": 1753660800,
  "ttl_days": 7,
  "validator": { "etag": "\"{GUID},7\"", "last_modified": "2026-07-22T14:03:11Z" },
  "hive": "orbit",
  "hit_count": 3
}
```

Timestamps are **epoch seconds**, compared against `date +%s` with integer arithmetic. This is
deliberate: GNU `date -d` and BSD/macOS `date -v` take incompatible flags, so any design that stores
a formatted date and computes an offset needs an OS branch. Integer comparison needs none.

---

## Exposure — the constraint that gates the default

Caching writes fetched content to disk **outside the Hive repo**, and that is a materially different
exposure question than reading the same bytes into a turn. Specifically:

- The cache root is not covered by the Hive's protection model.
- **Sentinel does not scan it.** Same structural limitation `sources-policy.md` documents for
  LFS-tracked binaries: the gate is a pre-push hook, and nothing here is ever pushed.
- The cache **outlives the session** that judged the fetch appropriate.

Therefore:

- **Default `enabled: false` for every Hive.** Caching is opt-in via
  `hive.yml.cache.enabled: true` — a deliberate act by codeowners who accept
  unscanned fetched content on local disk.
- A locator whose entry is marked `cite-only` (proposed in `BACKLOG.md` § fetch-disposition) is
  **never cached**, independent of the `enabled` setting. Material that should not be mirrored into
  context certainly should not be mirrored onto disk.
- Cache-clear must be a documented one-liner (`rm -rf` the Hive's partition) so a user who realizes
  they cached something sensitive has an immediate remedy.

This is the boundary `BACKLOG.md` flagged. This design does not resolve the broader question of
whether fetched content should ever be scanned or mirrored to disk at all — it declines to *widen*
that exposure by defaulting to off unconditionally, leaving the opt-in decision to codeowners.

---

## Promotion — the cache measures what §Extract only guesses

`routing-protocol.md` §Extract already says a repeatedly-needed binary belongs in `sources/` via
Deposit. Today that judgment rests on a single session's guess about a pattern spanning sessions,
which no session can see.

`hit_count` makes it observable. When an entry crosses a threshold (proposed: 3 hits across distinct
sessions), the agent offers Deposit: *"this ICD has been fetched three times this week — deposit it
to `sources/` so it stops costing a download?"* The user decides; the agent does not deposit
autonomously (`sources-policy.md`: deposits require explicit user intent).

This is the cache paying for itself twice — once in saved downloads, once as the only available
signal for a decision the protocol already wants made.

---

## Concurrency and eviction

**Two sessions, same URL, same moment.** Write body and `meta.json` to a temp name in the same
directory, then `mv` into place. Rename within one filesystem is atomic on APFS, ext4, and NTFS, so
a reader sees either the old entry or the new one — never a half-written body. No lockfiles: a stale
lock from a killed session would block every future fetch, trading a rare race for a permanent
outage.

**Eviction is opportunistic, never a daemon.** On any cache access, drop entries past their TTL. A
background process would be a fourth cross-OS scheduling mechanism (launchd / systemd / Task
Scheduler) for a problem that a `find`-and-delete on access solves.

---

## Design Goals compliance

| Goal | Bearing on this design |
|---|---|
| 1 — Reference, don't duplicate | **The tension.** A cache *is* a local copy. Reconciled because it is not part of the knowledge base, is never cited as a source, and is invalidated against the canonical document rather than diverging from it. Goal 1 forbids duplication *in `knowledge/`*; the failure it prevents is a stale copy presented as current, which the validator gate is built to stop. |
| 2 — Progressive discovery | Unaffected. The cache changes fetch cost, not what an entry says or whether to follow it. |
| 3 — Sensitivity is Hive-local | **The binding constraint driving this section's rename to § Exposure.** Drives unconditional default-off, per-Hive partitioning, and the documented Sentinel gap. |
| 4 — Collective ownership | Unaffected. The cache is per-user and holds nothing shared; no `knowledge/` write path is touched. |
| 5 — Contribution flywheel | Positive — `hit_count` creates a Deposit prompt that did not previously exist. |
| 6 — Size budgets | This file is `references/`, loaded on demand, and adds no lines to any always-loaded protocol file. The `tool-tiers.md` change is one column. |
| 7 — Temporal annotations | Not applicable to cache entries (not facts). `fetched_at` is the analogous provenance and is mandatory. |
| 8 — Upstream governance | Caching mechanics are protocol → upstream. Only `hive.yml.cache.*` is per-Hive. |
| 9 — Discoverability | **Explicitly exempt** — argued above under § What the cache is not. The cache is not a content surface, so it needs no index, no write path, and no audit check. |

---

## Open questions

1. **Does the agent reliably execute this?** The Apiary is prose protocol, not scripts. A five-state
   resolution table plus canonicalization plus atomic-rename is more procedure than any current
   §Resolve step. If adherence proves unreliable, the mechanism wants a helper script — which is a
   dependency-surface decision (`sources-policy.md` deliberately keeps the Apiary at bash + jq).
2. **`.xlsx` bodies or parsed output?** Caching the binary saves the download; caching `extract`'s
   parsed markdown saves download *and* parse. The latter overlaps `/extract:ingest`, which
   amortizes parse for material entering `sources/`. Probably: cache the body, let `extract` own
   parse-caching, and keep the boundary `external-retrieval-design.md` already draws.
3. **Is 7 days right?** Arbitrary until there is hit-rate data. Because validators protect
   correctness, TTL length trades disk against re-download frequency only — a safe knob to tune
   later, and a reason to keep it in `hive.yml` rather than hardcoded.
4. **Folder-level locators.** A store-relative row naming a folder resolves to a listing, not a
   document. Cache the listing (cheap, changes often) or only leaf documents? Leaning leaf-only.
