---
layer: PROTOCOL
type: external-search-agent
description: "Dispatch contract for the live store-search subagent — how the RLDP widens the corpus with a fresh query, what the agent is told, and the asymmetric read/write line it must not cross."
last_updated: 2026-07-30
codeowners: (read from hive.yml)
---

# External Search Agent — Live Store Query

**Purpose:** Query a live store the Hive has already indexed for documents no catalog row names, and
return them as ranked, catalog-shaped candidates — never as citable prose.
**Dispatched from:** `protocol/routing-protocol.md` §Search
**Design rationale:** `references/external-retrieval-search-design.md`

A catalog is a point-in-time view of a store that keeps being written to, so the corpus can never be
assumed complete. This agent closes the gap for one asked question at a time. It runs as a subagent
because search output is high-volume and mostly discarded: dozens of hits, each with a path, ID,
size, date, and author, are consumed here and reduced to a handful of rows, so the noise never enters
the main context (`references/external-retrieval-search-design.md` § Why a subagent, and what it must
be told).

---

## Dispatch Contract

Dispatched as a **subagent** from §Search after the main agent has run the pre-dispatch user prompt.
The agent cannot prompt the user — `AskUserQuestion` is main-agent-only
(`protocol/security-policy.md` Layer 0) — so scope is fully settled before dispatch and the agent
never comes back for it.

**Inputs handed to the agent (nothing else):**

| Input | Why it is handed down |
|---|---|
| The **question, verbatim** | What it is searching for. |
| **Domain vocabulary** — the `## Scope` headers and `covers` text the main agent already loaded at §Filter/§Match | Translates the user's phrasing into the store's. "How does the satellite talk to the ground" does not keyword-match `Space-to-Ground ICD`; without this the agent finds nothing and reports the store empty. |
| The **filesystem path(s)** to every `type: index` catalog covering the store (the PATHS, not their contents) | The agent greps them itself to dedup — full coverage, and the catalogs' hundreds of lines stay out of the main context. A nested Hive may hold more than one catalog per store; dedup is only as complete as the set handed down. |
| **Store roots + authorized scope** | Default: the roots the catalog declares in frontmatter `sources[]`. Tenant-wide only when the user explicitly authorized it. |
| **Effort tier** | `low` \| `medium` (default) \| `high` — governs whether the agent reads (§ Behavior by effort tier). |
| **Store kind + its search tool** | The `sources[].type` value and the tool that reaches it, from `protocol/tool-tiers.md` § Store Kind → Tool. |

**Outputs:** the catalog-form rows and ≤3-line summary defined in § Output shape. The agent writes
no file and stages no change — the main agent owns promotion at §Extract.

**Scope and re-entry** are the dispatcher's to settle, and §Search states them: once per store per
question, at most 2 stores, never from inside a §Recurse traversal. Two consequences land here:

- A catalog surfaced by §Recurse that declares a *different* store is grepped, never searched. If that
  store looks worth searching, it is a coverage gap for the main agent to record per §On no match — not
  a second search.
- Where **no catalog covers the store**, a search may still run: a reference-library entry pointing at
  an external URL establishes that the Hive indexes that store. But promotion then has no target, so
  the main agent records the missing catalog as a `[process]` gap rather than creating one. Catalog
  creation is authored work.

**When the store has no search tool** in `protocol/tool-tiers.md` § Store Kind → Tool, return the
no-tool failure below; the main agent records it per §On no match. Never improvise a tool.

---

## Behavior by effort tier

The tier sets **how hard to look**, not how many results to allow. Open every candidate that clears
the relevance bar for the tier — a query that surfaces six plausible documents should return six
verdicts, not an arbitrary top-N slice of them.

| Tier | Queries | Opens |
|---|---|---|
| `low` | the direct query | nothing — `covers` left empty on every row; the main agent opens the winner |
| `medium` (default) | the direct query | every hit whose name, path, and date make it a **plausible answer to the question**, not merely a keyword match |
| `high` | the direct query plus alternate phrasings until they stop surfacing new documents | same bar as `medium`, applied to the wider result set |

**The bar, stated so two agents apply it the same way.** Open a hit when its name and location suggest
it is *about* the question's subject — the same judgment §Prefer makes on a catalog row's `covers`. Do
not open a hit that matched only on an incidental term (a passing mention, a shared word in an
unrelated title), sits in a Skip-criteria location, or is a duplicate of a hit already opened. When
nothing clears the bar, return the ranked candidates unopened and say so.

**Cost is bounded by relevance, not by a count.** A well-scoped query against a declared store root
returns few plausible hits, so the bar is the budget. Where a query returns an implausibly large
plausible set — dozens — that is a signal the query was too broad: narrow it and re-run rather than
opening dozens of documents, and say in the summary that the query was narrowed.

The verification read at `medium` and above is worth its fetch: it stops the main agent spending
context on a document a title made look right and a first page proves wrong, and it produces the
`covers` text promotion requires, from the agent that has the document open
(`references/external-retrieval-search-design.md` § Why the verification read sits at medium effort).
The read produces a verdict and `covers` — **never citable prose.**

---

## Output shape

Catalog-form rows, ranked, one per discovered document:

```markdown
| Document | Location | covers | doc_type | authority | Last Modified | supersedes |
|---|---|---|---|---|---|---|
```

- `doc_type` and `authority` are **inferred from the path** per `protocol/document-quality.md`
  § Trawling Heuristics — that section owns the gates, and a Hive may reorder or extend them.
  Inference is good enough to *rank* a candidate and never good enough to *describe* one.
- `covers` is populated **only for documents the agent actually opened**, left empty otherwise. This
  is what lets §Extract promote an opened row at authored quality while an unopened row stays a
  candidate. Every row that clears the tier's relevance bar is opened, so at `medium` and above most
  rows carry `covers` — not just the top one.
- `supersedes` is set only on a row that is a newer revision of a catalogued document (§ Dedup rule),
  naming the version it replaces. Empty otherwise.
- Mark each opened row with its **topicality verdict** (on-topic yes/no). An off-topic verdict is not a
  reason to drop the row — it is still a real gap in the catalog, and §Extract promotes it with
  accurate `covers`.
- Plus a **≤3-line summary**: what was searched, how many hits, how many cleared the bar and were
  opened, how many were dropped as duplicates. **If a query was narrowed because its plausible set was
  implausibly large, say so** — a silent narrowing reads as complete coverage.

---

## MUST NOT (the asymmetric read/write line)

The agent **reads** to dedup and verify; it **writes** nothing. Stated explicitly:

- **MUST NOT write ANY file** — not `knowledge/`, not `_inbox/`, not a catalog. Promotion is the main
  agent's job at §Extract, which writes only a `[link]` inbox contribution; Parliament appends the
  catalog row. Neither the write nor the merge happens here.
- **MUST NOT commit, push, or otherwise touch git.**
- **MUST NOT widen its own scope** beyond what was authorized. On an unusable scope it returns empty
  with a reason — it never compensates by searching wider (it cannot ask, so it cannot escalate).
- **MUST NOT return citable document prose** — only locators, metadata, and topicality verdicts.
  Returning a summary the main agent then answers from would rebuild the paraphrase-a-cached-summary
  failure §Extract exists to prevent, differing only in that the cache is fresher
  (`references/external-retrieval-search-design.md` § Why judgment is the hard part). An assertion
  *about* a document — on-topic, what it covers — is metadata and is allowed; the document's contents
  are not. The main agent opens what it cites.
- **MUST NOT prompt the user.** It has no `AskUserQuestion`; everything it needs arrived at dispatch.

It **MAY read** the `type: index` catalog (to dedup) and, from `medium` upward, the documents it
verifies.

---

## Dedup rule — three outcomes, not two

Compare every hit against the covering catalogs at the handed-down paths, matching on document name
and location. A hit is one of three things, and only the first is discarded:

| Hit is | Outcome |
|---|---|
| The **same document, same version** already catalogued | Not a discovery — drop it. |
| A **newer version of a catalogued document** | A discovery, and the most valuable kind. Return it marked `supersedes: {the catalogued version}`. |
| **Absent from every catalog** | A discovery. Return it. |

**The supersession case is the one this protocol exists to catch.** A catalog goes stale mostly by
revision, not by omission: the row names Rev A and the store now holds Rev C. Treating that as a
duplicate would discard the freshest answer available and leave the corpus pointing at a superseded
document — the exact failure §Search was added to fix. Signals that a hit is a new revision rather
than a different document: the same name modulo a revision or date token (`Rev A` → `Rev C`,
`RevB 08.07.2025` → `RevC 11.20.2025`), the same location, a later modification date.

`supersedes` is an existing field with existing semantics — `protocol/document-quality.md`
§ supersedes owns the format, and the rule that a still-present superseded document is re-marked
`authority: baseline` is that section's, applied by Parliament when it merges the row. Do not invent a
parallel convention.

Also drop a hit a trawl would decline to catalog — the Skip criteria in
`protocol/document-quality.md` § Trawling Heuristics (archived copies, duplicates of a catalogued
document, material that matches no gate). Search must not inject the class of row the trawl gates
exist to exclude.

---

## Failure modes

Each returns **empty with a reason** — never a widened search:

| Condition | Return |
|---|---|
| Scope unusable or empty (no authorized root) | `search: skipped (no usable scope)` |
| No search tool for the store kind | `search: skipped (no <kind> search tool — see tool-tiers.md)` — the main agent records this per §On no match |
| Store unreachable (auth, 401/403, timeout) | `search: skipped (<reason>)` |
| Query ran, nothing after dedup | `search: 0 new (N hits, all in catalog)` |

Never widen scope to compensate for a failure. A store that answered nothing on a well-formed query
will not answer more on an unauthorized one, and widening is the exact exposure the classification
default guards against.
