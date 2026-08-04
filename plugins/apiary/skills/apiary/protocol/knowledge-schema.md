---
layer: PROTOCOL
type: schema-spec
description: "Canonical schema for knowledge-file frontmatter across all Hive Minds governed by the Apiary. Machine-enforced via assets/knowledge-entry.schema.json."
last_updated: 2026-04-24
codeowners: (read from hive.yml)
---

# Knowledge File Schema

Every file in `knowledge/**/*.md` must carry frontmatter conforming to this schema. The **machine-readable** version is `assets/knowledge-entry.schema.json` — this document is the prose companion.

## Required Fields

| Field | Type | Description |
|-------|------|-------------|
| `domain` | string (kebab-case) | Top-level domain. Usually matches the `knowledge/` subdirectory. |
| `type` | enum | `reference` \| `register` \| `status` \| `index` \| `reference-library` |
| `description` | string (10–500 chars) | One-line summary. Used by agents to decide whether to load. |
| `decay` | enum | `fast` \| `medium` \| `slow` |
| `confidence` | enum | `low` \| `medium` \| `high` |
| `last_updated` | ISO 8601 date | YYYY-MM-DD |

## Conditionally Required

| Field | When required |
|-------|--------------|
| `review_by` | Required when `decay: fast`. Recommended otherwise. |

## Optional

- `sources`: array of citation strings or `{path, url, doc, type}` objects. On a `type: index` catalog this field is **load-bearing**, not decorative — it declares the store root that the catalog's rows resolve against (see § Store Roots for `type: index` Catalogs).
- Hives may declare **additional** required fields via `extensions.knowledge_schema` in `hive.yml` (see `references/mode-operate.md` § Merge Extensions).

## Type Semantics

| type | What it is | Example |
|------|-----------|---------|
| `reference` | Stable facts that change slowly (architecture, overview). | `knowledge/ground-segment/architecture.md` |
| `register` | Tables maintained over time (risks, decisions, stakeholders). | `knowledge/program/risks.md` |
| `status` | Current state that decays fast (deliverable status, CDR gates). | `knowledge/ground-segment/integration-status.md` |
| `index` | Pointers to external systems (Confluence, document catalogs). | `knowledge/program/confluence-index.md` |
| `reference-library` | Corpus index with retrieval triggers — auto-discovered by the Ask workflow. One per knowledge domain or at the root. Must have `## Scope` header. | `knowledge/reference-library.md` or `knowledge/ground-segment/reference-library.md` |

Agents route based on `type`. Incorrectly typed content (e.g., a fast-decay status file tagged as `reference`) will not get the freshness treatment it needs.

### Reference Library Entry Format

A reference-library is a **routing index, not a content store.** Its job is to tell Ask *which knowledge file to load* for a given question — not to reproduce the information that knowledge file contains. This keeps the reference-library small (it's loaded speculatively during Ask routing) and avoids duplicating URLs, facts, or details that already have a canonical home.

**Default format: a compact table per `##` section.** One row per entry, three columns — `Topic | Source | Triggers`:

```markdown
## {Category}

| Topic | Source | Triggers |
|---|---|---|
| {short entry name} | `program/overview.md` § {section} | {comma-separated phrases/keywords that should match} |
```

Source cells are written **relative to `knowledge/`** (`program/overview.md`, not `knowledge/program/overview.md`) — the shorter form keeps cells dense, and audit resolves them against `knowledge/` (see `references/mode-audit.md` Step 1b). Block-form `**Source:**` labels may still carry the full `knowledge/…` prefix; both resolve.

The table is the default because it is objectively denser than the block form: no `###`-header / `**Source:**` / `**Triggers:**` / blank-line overhead per entry, so a library holds far more routing per token — the whole point of a speculatively-loaded index. Triggers stay plain comma-separated text in the last column, so keyword scanning works exactly as before.

**Block form — escape hatch, not the default.** A handful of entries genuinely need a sentence of routing context that doesn't fit a cell (e.g. "the config body lives in PR #38, not the Hive — this file holds only the durable findings"). For those, use the block form and keep the prose to a single `**Note:**` line:

```markdown
### {entry-name}
**Source:** {knowledge file path} § {section name}
**Triggers:** {comma-separated keywords}
**Note:** {one line of routing context — where the real content lives, a caveat, or a cross-instance pointer}
```

Do not mix a `**Note:**` into a table cell (it bloats the column); promote just that entry to block form, or collect the handful of notes under a single trailing `**Note:**` paragraph at the end of the file. If a note grows past one line, it belongs in the target knowledge file, not the router.

**Source** should point to a knowledge file (or section within one) whenever possible. For skills/tools entries, use `Install:` / `Fallback:` columns (or fields) instead of `Source:`.

**External material belongs behind a catalog, not in the router.** A reference-library is a thin routing index over `knowledge/` (`design-goals.md` §1). When the answer lives in an external store, the sanctioned shape is two hops — router row → `type: index` catalog → the document — because the catalog is where a store root, `doc_type`, and `authority` can be declared once and shared by every row. A raw external URL directly in a Source cell is the **escape hatch**, acceptable only when no knowledge file or catalog covers the topic; it carries no store root and no trust metadata, so it is the weakest form of the pattern. If you find yourself adding a second raw URL to a router, that is the signal to create the catalog.

**Directory pointers.** A Source cell may name a **directory** with a trailing slash (`people/profiles/`) instead of a file. This covers every `.md` file in that directory with one row and is the correct form for a set of files that share retrieval triggers and grow over time — per-person profile cards, per-service catalog entries.

- **Coverage semantics:** a directory pointer covers every `.md` at that path, recursively. Audit resolves it that way (`references/mode-audit.md` Step 1b), so those files are *not* orphans.
- **When to use it:** the set is open-ended and homogeneous — new members need no new routing decision. A profiles directory qualifies; three unrelated architecture files do not.
- **When not to:** if a reader needs to know *which* file in the directory answers their question, list the files. A directory pointer says "any of these, scan them"; that is only acceptable when the files are individually small and uniformly shaped.
- A directory pointer does **not** exempt the directory from having useful triggers. The triggers must still name the entities inside it — for a profiles directory, list the people by name.

Entries are grouped under `##` section headers by category (e.g., `## Source Code & Repos`, `## Confluence & Docs`, `## Skills & Tools`). The `## Scope` header at the top describes what domain this library covers — the Ask workflow reads only this header when filtering for relevance.

**Placement:** Hives with nested `knowledge/` subdirectories should place one `reference-library.md` per subdomain. Flat hives (all knowledge at `knowledge/` root) should use a single `knowledge/reference-library.md`.

**Aggregation:** Group related resources into a single row when they share retrieval triggers. Ten repos in one "Integration repos" row is better than ten rows with similar triggers — fewer entries means faster matching and less token overhead.

**Size:** reference-libraries are thin routers. Audit flags any over 200 lines (see `references/mode-audit.md` Step 1b); the table format is the primary lever for staying under it. If a library is over threshold, convert block entries to table rows before cutting coverage.

## Inline Annotations

Frontmatter is **per-file**; some provenance and staleness signals attach to a **single fact or line** instead. Those use inline annotations in the file body. They are written at author-time and never mutated at read-time — read-time usage telemetry (access counts, retrieval trails) belongs in a disposable retrieval cache, not in knowledge content.

| Annotation | Purpose | Required? |
|---|---|---|
| `[learned: YYYY-MM-DD]` | When the fact entered the system | Required on every new fact |
| `[effective: YYYY-MM-DD]` | **When the fact became true in the world** — distinct from when it was learned | Optional; apply whenever the two dates differ |
| `[review-by: YYYY-MM-DD]` | When the fact should be re-verified | Required for `decay: fast`, recommended otherwise |
| `[decided: <who>, YYYY-MM-DD]` | **Epistemic provenance** — a decision was made, by `<who>` (human name or agent id) | Optional; apply whenever a *choice* was made (not for observed/inferred facts) |
| `[superseded: YYYY-MM-DD, reason]` | Marks a fact as replaced | Used when updating, not deleting |
| `[disputed: YYYY-MM-DD]` | Marks a fact with contradicting claims | Added by Loop D (Escalation) / Parliament contradiction handling |

### `[effective:]` — world-validity, as distinct from ingestion time

`[learned:]` records when a fact **entered the Hive**. Every freshness judgment downstream then
runs on that clock: `§Prefer`'s status rule ranks "the most recent" candidate, and Audit's
staleness check measures from file-write dates. For most facts the two clocks agree closely enough
that nothing breaks. For the facts that matter most in a status question, they do not:

- A fact backfilled today about a decision made last quarter is the **oldest** fact in the set and
  the **newest** by `[learned:]`. Ranked on ingestion, it wins — and the answer is wrong.
- A fact written eight months ago that is still true reads as stale on both clocks, and gets
  caveated or demoted in favor of something newer but less accurate.

`[effective:]` states the one thing that resolves both: **when this became true in the world.**

- **Means:** the fact holds as of this date. It is not a claim about when anyone learned it, wrote
  it down, or verified it.
- **Apply when** the two dates differ meaningfully — backfilled history, a decision recorded after
  the fact, a status that changed on a date other than the day it was noticed, anything imported
  from a source dated earlier than the deposit. When they are the same day, `[learned:]` alone is
  enough; do not add noise.
- **A fact may carry both**, and normally does: `[effective: 2026-05-01] [learned: 2026-08-03]`
  reads "true since May, we found out in August."
- **Never infer one.** If the world-validity date is not stated by the source, leave the annotation
  off. A guessed `[effective:]` is worse than none, because §Prefer ranks on it mechanically — the
  same rule `[decided:]` holds for `<who>`.
- **Absence means "unknown, use `[learned:]`"** — never "effective on the learned date." The
  fallback is a ranking convenience, not an assertion about the world.

**Optional by construction.** Existing facts carry no `[effective:]` and keep ranking exactly as
they do today; nothing needs backfilling and no file becomes invalid. Because it is inline rather
than frontmatter, `assets/knowledge-entry.schema.json` needs no new property — the same reasoning
that keeps `[decided:]` inline (a `register` file holds many rows, each with its own dates).

Consumers: `protocol/routing-protocol.md` §Prefer ranks status questions on it when present;
`references/mode-audit.md` Step 2 decays from it when present. Both fall back to the existing
clock when it is absent, so adoption can be gradual and per-fact.

### `[decided:]` — epistemic provenance

Frontmatter captures *when* a file changed (`last_updated`), how fast it decays, and how confident the agent is. What it does **not** capture is the *epistemic status* of an individual fact — whether it records a **decision** (a fork in the road) vs. an observed/inferred fact, and if a decision, **who made it** — a human, or an agent acting autonomously. `[decided:]` fills that gap.

The `<who>` sub-field carries the actor: a human name (in a Hive, the contributor/CODEOWNER) or an agent id (`claude`). Human-vs-agent falls out of reading `<who>`; the marker does not privilege one over the other.

This is deliberately an **inline annotation, not a frontmatter field.** The marker attaches to one fact, but frontmatter is per-file: a `register` file (e.g. a decisions log) holds many rows, each potentially decided by a different actor on a different date — a single frontmatter field cannot represent that granularity. Inline is the correct scope, and it keeps this schema consistent with the Second Brain schema. Because it is inline, `assets/knowledge-entry.schema.json` needs no new property.

- **Means:** a decision — a choice between viable alternatives — was made by `<who>` on this date. It records that a fork was taken, not merely that a fact is true.
- **Apply when:** *anyone* (human or agent) chooses a direction, commits to an approach, or resolves an option that could have gone another way. Written at author-time by whoever records the decision.  Pairs with `[learned:]` — a fact can carry both.
- **Decision ≠ inference — the line to hold.** An agent *deriving* a fact from evidence (reading a config, summarizing a doc) is NOT a decision and stays unmarked. An agent *choosing* between options that could have gone another way IS a decision and gets `[decided: <agent>, date]`. Blurring the two dilutes the signal and drags the marker toward per-fact telemetry, which it must not become.
- **Absence means "no decision recorded"** — an observation, an inference, or an unattributed fact. Absence is *not* "an agent decided."
- **Agent decisions are ratification candidates.** `[decided: <agent>, …]` marks a fork an agent took autonomously. A later human `[decided:]` on the same fact ratifies it (agent chose → human confirmed). Audit and Parliament surface unratified agent decisions for review (see `references/mode-audit.md`).
- **Never backfill.** A fabricated decider or date is worse than none. Apply going forward only; do not retro-attribute existing facts during bulk passes or Parliament merges.
- **who + date are one unit.** Following the `[superseded: date, reason]` grammar, both values live in one annotation, so the marker is either complete or absent — never half-fabricated.

**Worked example — human decision vs. agent decision vs. agent inference, side by side:**

```markdown
- Ground segment will target the KP7 Keycloak until PI-5; the 24.x bump is deferred. [decided: Jamie, 2026-07-14] [learned: 2026-07-14]
- Picked Keycloak over Authentik as the realm broker for the demo — both worked, chose the one already in the deployment. [decided: claude, 2026-07-14] [learned: 2026-07-14]
- The ground segment appears to authenticate via OIDC against Keycloak, inferred from the realm config in the deployment repo. [learned: 2026-07-14]
```

Line 1 is a human commitment — defensible years later as *a person chose this*. Line 2 is an **agent** choosing between viable options — a fork a human may want to ratify; attributed to `claude`, so audit/Parliament can surface it. Line 3 is agent *inference* from a config file — not a decision, so no `[decided:]`.

## Decay Semantics

| decay | Audit staleness threshold | When to use |
|-------|---------------------------|-------------|
| `fast` | 14 days | Current-state files (deliverable status, integration state, sprint-level information) |
| `medium` | 60 days | Stakeholder rosters, document indexes, process descriptions |
| `slow` | 180 days | Architecture overviews, mission definitions, assumptions established at baseline |

Audit mode (`mode-audit.md` Step 2) flags files whose `last_updated` exceeds the decay threshold.

## Store Roots for `type: index` Catalogs

A `type: index` catalog points at documents held in an external store. **An absolute URL per row is the preferred form** — it resolves with no context, survives being copied elsewhere, and is the only form that works for stores addressed by opaque ID (Quip threads, Box files, Confluence `pageId`, Jira keys) rather than by path.

Store roots exist for the one case where per-row URLs are genuinely wasteful: a **hierarchical document library** (SharePoint, OneDrive, Google Drive) where dozens of rows sit under a common root and repeating a 200-character URL per row would consume the budget the catalog exists to save. There, declare the root once in frontmatter and write rows relative to it — the same economy that lets reference-library Source cells omit the `knowledge/` prefix:

```yaml
sources:
  - url: "https://example.sharepoint.com/sites/{site}/Shared%20Documents/"
    type: sharepoint
```

```markdown
| Document | Location | doc_type | authority |
|---|---|---|---|
| Space-to-Ground ICD | `06 - Ground Segment/ICDs/` | icd | formal |
```

The row's location is not a resolvable address on its own; joined to the declared root, it is. This is what lets the RLDP reach the document (`protocol/routing-protocol.md` §Resolve).

**Most store-relative locations name a folder, not a file** — the document's own name sits in the `Document` column, because a folder trawl produces a folder map. Resolve such a row as root + `Location` + `Document`; when the filename is absent or approximate, resolve to the folder and list it. A folder-level row is legitimate (it answers "where does this class of document live"), but it costs an extra call and cannot be cited as a document until the file is identified.

**Requirement.** A `type: index` catalog whose rows carry store-relative locations **must** declare the store root in frontmatter `sources[]`, as `url` (the root) plus `type` (the store kind). Without it every row in the file is unresolvable and the catalog can only ever yield addresses — Audit flags this (`references/mode-audit.md` Step 1c). A catalog whose rows are all absolute URLs needs no root; declaring `type` per store is still useful so the agent knows what opens it.

- **`url`** — the root that rows resolve against. Prefer the deepest root all rows share; a row may still carry a full absolute URL, which takes precedence over the root.
- **`type`** — the store kind, so the agent knows which tool reaches it: `sharepoint`, `box`, `quip`, `confluence`, `jira`, `ghe`, `gitlab`, `public-web`. Extend the list when a Hive uses a store it does not name; keep values lowercase and one word. The store→tool mapping is `protocol/tool-tiers.md`.
- **More than one store** in one catalog is allowed — declare one `sources[]` entry per store. Where rows could resolve against either root, say which in the column header or a row note, or split the catalog.

**Prefer absolute URLs as retrieval improves.** A store-relative row costs a join and a correct root; an absolute URL costs neither. When adding rows to an existing hierarchical catalog, match the file's convention rather than mixing forms mid-table — but for a new catalog, or any store addressed by ID, write the URL.

**This is a store locator, not a content categorization.** `type` here answers *where does this live and what opens it*. What the document **is** and how much it should be trusted are `doc_type` and `authority`, defined in `protocol/document-quality.md`. Do not conflate them: a `specification` with `authority: formal` may live in any store, and the store says nothing about its trust.

Why the root lives in frontmatter rather than on every row: `references/external-retrieval-design.md`.

## Validation

Every Parliament run (Archivist pre-processing — `custodian-workflow.md` §2.1) validates proposed knowledge file changes against this schema. Child Hives may install a pre-commit hook to run the same validation locally. A pre-commit hook runs outside any Claude Code session, so it can't rely on agent-resolved placeholders — resolve the installed plugin's asset path once via the CLI and hardcode it in the hook script:

```bash
APIARY_ROOT=$(claude plugin list --json | jq -r '.[] | select(.id | startswith("apiary@")) | .installPath')
yq -o json path/to/knowledge-file.md | ajv validate -s "$APIARY_ROOT/skills/apiary/assets/knowledge-entry.schema.json"
```

## Source Document Taxonomy

When knowledge files catalog external documents (SharePoint, Confluence, vendor deliverables), source entries should carry `doc_type` and `authority` fields. See `protocol/document-quality.md` for the full taxonomy, trawling heuristics, and question-type routing guidance.

## Extensions

A Hive may require additional fields by declaring `extensions.knowledge_schema` in `hive.yml`. The declared file is a JSON Schema that is merged with the base schema at runtime. See `references/mode-operate.md` § Merge Extensions.
