---
layer: PROTOCOL
type: ways-of-working
description: "Structural patterns that recur across Hives — canonical organizational conventions for people directories, stakeholder tracking, cross-domain indices, and similar meta-structure. Captured once here so each Hive doesn't reinvent the shape."
last_updated: 2026-04-19
codeowners: (read from hive.yml)
---

# Ways of Working

Structural conventions that recur across Hives. These are **patterns**, not hard rules — a Hive can deviate with cause, but the default shape is captured here so every child Hive doesn't have to redesign common machinery.

Each pattern records: **what it is**, **why it works**, **when to use it**, and **where a reference implementation lives**.

---

## People Directory Pattern

**What it is:** A dedicated `knowledge/people/` directory that is the canonical source for roles, org affiliations, handles, and contact info across the Hive's domain.

**Structure:**

```
knowledge/people/
├── README.md              — entry point: structure, contribution rules, linking convention
├── internal.md            — Meridian Systems people, sub-grouped by function
├── external.md            — everyone else, sub-grouped by organization
├── uncertainties.md       — open questions (full names, duplicate records, role/org confirmations)
└── profiles/
    └── <person-slug>.md   — deep profile cards for people with engagement nuance worth recording
```

**Why this shape:**

- **Internal vs. external at the file level** prevents the two concerns from bleeding together in mixed tables. Internal and external engagement dynamics differ — customer relationships carry political context that employee records don't, and vice versa. Separate files keep each clean.
- **Sub-grouping within a file** (by function for internal; by organization for external) scales better than a flat table once the roster grows past ~15 entries.
- **Profile cards are the exception, not the rule.** Most entries belong only in the index table. A profile card exists only when there is engagement nuance worth recording — decision patterns, sensitivities, cross-domain relationships, historical context. Target ~5-10% of entries. This avoids profile sprawl that nobody reads.
- **Uncertainty tracker as a first-class file** acknowledges that a real-world roster always contains gaps: first-name-only references, spelling variations, ambiguous duplicates, unconfirmed titles. Recording these explicitly (with a resolution path) beats silently guessing.

**Contribution rules (bake these into the Hive's README):**

1. **Role + contact only** in the index tables. No personal editorial commentary about named individuals — that's a PROTOCOL behavioral constraint (see `PROTOCOL/security-policy.md` §PII and `agent-definition.md`). Engagement approach is acceptable in profile cards because it's professional context, not personal judgment.
2. **Do not guess.** If a full name, role, or org is uncertain, record what the source says and mark `[UNCERTAIN]` in the notes column. Full names should never be invented from a handle or first name.
3. **Temporal annotations.** Date facts that were learned at a specific moment (`[learned: YYYY-MM-DD]`). Titles and roles drift — dated facts let future readers know whether to re-verify.
4. **Profile threshold.** Create a profile card only when the person warrants one. If the same information would fit in a row of the index table, keep it in the table.

**Linking convention inside the Hive:**

- **Body-text markdown links** (`[name](profiles/name.md)`) are the standard for clickable cross-references — they render in both GHE and any markdown viewer.
- **Frontmatter links** only render clickably in Obsidian (with quoted wikilink strings like `manager: "[[person-slug]]"`). They remain raw text in GHE. Keep frontmatter plain by default; adopt wikilinks only if the Hive is consumed in Obsidian and the team values the graph-view indexing.

**When to invoke this pattern:**

Any Hive tracking more than ~10 distinct people. Below that, a single `stakeholders.md` table is usually fine. Migrate to this structure when:
- The flat table exceeds ~80 rows and scanning becomes painful.
- Engagement-nuance notes start crowding the row-per-person format.
- Multiple knowledge files need to reference the same person and start drifting on their canonical role.

**Migration path from a flat `stakeholders.md`:**

1. Create `knowledge/people/{README,internal,external,uncertainties}.md` and `profiles/`.
2. Split the existing table contents: Meridian Systems people → `internal.md`; customer/partner/contractor → `external.md`.
3. Port any existing profile cards (or promote the most-referenced individuals from the flat file).
4. Harvest open questions into `uncertainties.md` — `[UNCERTAIN]` flags from the source, missing full names, duplicate-looking records.
5. Add a redirect banner at the top of the old `stakeholders.md` pointing to `people/README.md`. Keep the old file until other knowledge files have been updated to link to the new location, then retire it.

**Reference implementation:**

Orbit Hive — [`knowledge/people/`](../../../../../../orbit/orbit-hive/knowledge/people/) (path relative to this file, for developers working across the monorepo). Prototype introduced 2026-04-19.

---

## When to Add a Pattern Here

A pattern graduates into this file when:

1. Two or more Hives have independently arrived at the same structural shape.
2. A single Hive solves a non-obvious structural problem and the Apiary CODEOWNERS agree other Hives would benefit.
3. A migration from a simpler structure to a more scaled one has been executed, and the migration path itself is worth capturing so the next Hive doesn't repeat the discovery.

Patterns that only apply to one Hive's domain (e.g., "CDR close-plan tracker" for a program Hive) do **not** belong here — those stay in the Hive's own `knowledge/`. This file is for structural conventions shared across all Hives only.

Propose new patterns by editing this file in the Apiary repo and opening a PR.
