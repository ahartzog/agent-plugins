---
type: protocol
description: "Canonical schema for knowledge-file frontmatter in Second Brain agents"
last_updated: 2026-07-30
---

# Knowledge File Schema

Every knowledge file in a Second Brain agent must carry YAML frontmatter conforming to this schema. This is the authoritative definition — agent templates and audit checks reference this file.

## Required Fields

| Field | Type | Description |
|---|---|---|
| `domain` | string (kebab-case) | Domain this file belongs to. Usually matches the agent/folder name. |
| `type` | enum | `reference` \| `register` \| `status` \| `index` \| `reference-library` |
| `description` | string (10-500 chars) | One-line summary. Used by agents to decide whether to load. |
| `decay` | enum | `fast` \| `medium` \| `slow` |
| `confidence` | enum | `low` \| `medium` \| `high` |
| `last_updated` | ISO 8601 date | YYYY-MM-DD — when this file was last meaningfully updated |

## Conditionally Required

| Field | When Required |
|---|---|
| `review_by` | Required when `decay: fast`. Recommended otherwise. |
| `sources` | Required when file indexes external content (Confluence, Jira, repos) |

## Optional

| Field | Type | Description |
|---|---|---|
| `sources` | array | Citation strings or `{path, url, doc, type}` objects pointing to external sources |
| `tags` | array of strings | Free-form tags for cross-referencing |

## Type Semantics

| Type | What It Is | Decay Default | Example |
|---|---|---|---|
| `reference` | Stable facts that change slowly (architecture, overview) | `slow` | `architecture.md` |
| `register` | Tables maintained over time (risks, decisions, stakeholders) | `medium` | `stakeholders.md` |
| `status` | Current state that decays fast (deliverable status, sprint items) | `fast` | `integration-status.md` |
| `index` | Pointers to external systems (Confluence, document catalogs) | `medium` | `confluence-index.md` |
| `reference-library` | Corpus index with retrieval triggers — auto-discovered by agent routing | `slow` | `reference-library.md` |

Agents route based on `type`. Incorrectly typed content (e.g., a fast-decay status file tagged as `reference`) will not get the freshness treatment it needs.

## Decay Semantics

| Decay | Audit Staleness Threshold | When to Use |
|---|---|---|
| `fast` | 14 days | Current-state files (deliverable status, integration state, sprint-level) |
| `medium` | 60 days | Stakeholder rosters, document indexes, process descriptions |
| `slow` | 180 days | Architecture overviews, mission definitions, established assumptions |

Audit mode flags files whose `last_updated` exceeds the decay threshold.

## Reference Library Entry Format

A reference-library is a **routing index, not a content store.** Its job is to tell the agent *which knowledge file to load* for a given question — not to reproduce the information that knowledge file contains. This keeps the reference-library small (it's loaded speculatively during routing) and avoids duplicating URLs, facts, or details that already have a canonical home.

**Default format: a compact table per `##` section.** One row per entry, three columns — `Topic | Source | Triggers`:

```markdown
## {Category}

| Topic | Source | Triggers |
|---|---|---|
| {short entry name} | `overview.md` § {section} | {comma-separated phrases/keywords that should match} |
```

The table is the default because it is objectively denser than the block form: no `###`-header / `**Source:**` / `**Retrieval triggers:**` / blank-line overhead per entry, so a library holds far more routing per token — the whole point of a speculatively-loaded index. Triggers stay plain comma-separated text in the last column, so keyword scanning works exactly as before.

**Block form — escape hatch, not the default.** A handful of entries genuinely need a sentence of routing context that doesn't fit a cell. For those, use the block form and keep the prose to a single `**Note:**` line:

```markdown
### {entry-name}
**Source:** {knowledge file path} § {section name}
**Triggers:** {comma-separated keywords}
**Note:** {one line of routing context — where the real content lives, or a caveat}
```

Do not mix a `**Note:**` into a table cell (it bloats the column); promote just that entry to block form. If a note grows past one line, it belongs in the target knowledge file, not the router.

**Source** should point to a knowledge file (or section within one) whenever possible. Only use a direct external URL when no knowledge file covers the topic. For skills/tools entries, use `Install:` / `Fallback:` columns (or fields) instead of `Source:`.

Entries are grouped under `##` section headers by category. The `## Scope` header at the top describes what domain this library covers — agents read only this header when filtering for relevance.

**Placement:** One `reference-library.md` per domain folder. Agents with nested subfolders may have one per subfolder.

**Aggregation:** Group related resources into a single row when they share retrieval triggers. Ten repos in one "Integration repos" row is better than ten rows with similar triggers — fewer entries means faster matching and less token overhead.

**Size:** reference-libraries are thin routers. Audit flags any over 200 lines (see `references/mode-audit.md`); the table format is the primary lever for staying under it. If a library is over threshold, convert block entries to table rows before cutting coverage.

## Inline Annotations

Knowledge file content uses inline annotations for provenance and staleness:

| Annotation | Purpose | Required? |
|---|---|---|
| `[learned: YYYY-MM-DD]` | When the fact entered the system | Required on every new fact |
| `[decided: <who>, YYYY-MM-DD]` | **Epistemic provenance** — a decision was made, by `<who>` (human name or agent id) | Optional; see Provenance below |
| `[review-by: YYYY-MM-DD]` | When the fact should be re-verified | Required for `decay: fast`, recommended otherwise |
| `[superseded: YYYY-MM-DD, reason]` | Marks a fact as replaced | Used when updating, not deleting |
| `[disputed: YYYY-MM-DD]` | Marks a fact with contradicting claims | Added by Loop D |
| `[confidence: low]` | Inline flag for unverified claims | Required when presenting decisions with real stakes |

### `[decided:]` — epistemic provenance

`[learned:]` captures *when* a fact arrived; `[decided:]` captures *that a decision was made and who made it.* Years later, "we chose X" must be distinguishable along two axes: **was it a decision at all** (a fork in the road) vs. an observed/inferred fact, and if so **who decided** — a human, or an agent acting autonomously.

The `<who>` sub-field carries the actor: a human name (`Alek`) or an agent id (`claude`). Human-vs-agent falls out of reading `<who>` — the marker does not privilege one over the other.

- **Means:** a decision — a choice between viable alternatives — was made by `<who>` on this date. It records that a fork was taken, not merely that a fact is true.
- **Apply when:** *anyone* (human or agent) chooses a direction, commits to an approach, or resolves an option that could have gone another way. Written at author-time by whoever records the decision. Pairs with `[learned:]` (a fact can carry both).
- **Decision ≠ inference — the line to hold.** An agent *deriving* a fact from evidence (reading a statement, summarizing a document) is NOT a decision and stays unmarked. An agent *choosing* between options that could have gone another way IS a decision and gets `[decided: <agent>, date]`. Blurring the two dilutes the signal and drags the marker toward per-fact telemetry, which it must not become.
- **Human decisions pass the quote test.** A fact may carry `[decided: <human>, …]` only if the decision actually happened — the bar is being able to quote the human's actual words. Deliberation and scoping questions are inputs, not decisions. Sparse use is the point — if everything is marked, the marker says nothing.
- **Absence means "no decision recorded"** — an observation, an inference, or an unattributed fact. Absence is *not* "an agent decided."
- **Agent decisions are ratification candidates.** `[decided: <agent>, …]` marks a fork an agent took on its own. A later human `[decided:]` on the same fact ratifies it (agent chose → human confirmed). Audit surfaces unratified agent decisions for review (see `references/mode-audit.md`).
- **Never backfill.** A fabricated decider or date is worse than none (same rule as never-backdating `[learned:]`). Apply going forward only; do not retro-attribute existing facts during bulk passes.
- **who + date are one unit.** Following the `[superseded: date, reason]` grammar, both values live in one annotation — a decider with no date (or vice versa) is exactly the half-fabricated marker the never-backfill rule guards against.

**Worked example — human decision vs. agent decision vs. agent inference, side by side:**

```markdown
- 529 contributions stay at $500/mo through 2026; we will not front-load this year. [decided: Alek, 2026-07-30] [learned: 2026-07-30]
- Picked Marcus over Ally for the emergency-fund HYSA — both cleared the rate threshold; chose the one already linked in the budget tool. [decided: claude, 2026-07-30] [learned: 2026-07-30]
- The mortgage appears to have no prepayment penalty, inferred from the loan disclosure PDF. [learned: 2026-07-30]
```

Line 1 is a human commitment — defensible years later as *a person chose this*. Line 2 is an **agent** choosing between viable options — a fork that a human may want to ratify; it's attributed to `claude`, so audit can surface it. Line 3 is agent *inference* from a document — not a decision, so no `[decided:]`.

## Validation

Audit mode (`references/mode-audit.md`) validates knowledge file frontmatter against this schema. Missing required fields are flagged as Important findings. Incorrect type/decay combinations are flagged as Minor.

## Source Tracking

Knowledge files with `sources:` frontmatter participate in mechanical staleness detection via `.staleness-manifest.json` at the hub root. On each `/second-brain audit` run:

- Sources are re-fingerprinted and compared to the manifest
- If a source changed but the knowledge file wasn't updated → flagged as **sync-stale**
- The manifest is a gitignored cache — regenerated on first audit after a fresh clone
