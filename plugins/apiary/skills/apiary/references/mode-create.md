# Create Mode — New Hive Scaffolding

This document guides the Create mode of the Apiary skill. Follow these steps exactly.

## Prerequisites

SKILL.md has already confirmed: no `hive.yml` found in cwd (or user explicitly requested create).

## Step 0: Source Material Audit (BEFORE interviewing)

Before Step 1, ask: **"Is there existing content this Hive should be seeded from? This could be a personal Second Brain, a doc corpus, a set of Confluence pages, or nothing (greenfield)."**

If the user points to an existing corpus:

1. **Read the corpus before interviewing.** Key fields (name, description, codeowners, slack channel, knowledge topics) can often be inferred — do NOT ask questions the corpus already answers.
2. **Ask for sanitization directives explicitly.** The corpus may contain material unsafe for a shared Hive:
   - Personal editorial commentary about named individuals → strip to role + contact only
   - Classification markers (CUI, FOUO, SECRET, `[INTERNAL]` flags) → reference by path; never reproduce
   - Local filesystem paths (OneDrive, vault, home dir) → map to canonical URLs (SharePoint, GHE, Confluence); mark unconfirmed URLs as `{path TBD}`
   - Personal workflow modes (user-specific 5-15 generation, Outlook trawling, voice skills) → exclude; agent is a team persona
3. **Propose a draft hive.yml + knowledge layout** based on the corpus, then confirm with the user before generating. **When in doubt, exclude.** A sparse Hive that grows through contribution is healthier than a dense one that leaks personal or internal content.
4. Skip any Step 1 question the corpus + confirmation already answered.

If greenfield, proceed directly to Step 1.

## Step 1: Interview

Ask these questions **one at a time** using `AskUserQuestion`. Do not batch.

### Q1: Domain Name
"What domain does this Hive cover? This should be a program name, integration area, or team focus."

Examples: "Widget Integration", "Platform Security", "Platform Onboarding"

Store as `{HIVE_NAME}`. Derive `{HIVE_SLUG}` as kebab-case (e.g., "Widget Integration" → "widget-integration").

### Q2: Description
"One-sentence description of this Hive's purpose."

Store as `{DESCRIPTION}`.

### Q3: Persona
"Who is this AI agent? Give it a name and describe its role."

Example: "Widget Integration Sherpa — helps Widget and Meridian Systems engineers understand each other's systems and track integration progress."

Store as `{PERSONA_NAME}` and `{SCOPE_SENTENCE}`.

### Q4: Codeowners
"Who should approve protocol changes and handle escalations? (GitHub usernames, comma-separated)"

Store as `{CODEOWNERS}` (array) and `{CODEOWNERS_CSV}` (comma string).

### Q5: Slack Channel
"Which Slack channel should the Signal bot post to for this Hive?"

Store as `{SLACK_CHANNEL}`.

### Q5.25: Git Remote
"What is the GHE remote URL for this Hive's repo? (e.g. `git@ghe.meridian.example:meridian/my-hive.git`)"

Store as `{GIT_REMOTE}`.

### Q5.3: Default Branch
"What is the default branch name? (default: `master`)"

Store as `{DEFAULT_BRANCH}`. Default to `master` if the user skips.

### Q5.5: Classification Ceiling
"What is the highest classification this Hive is authorized to store? (`UNCLASSIFIED` / `CUI`)

- `UNCLASSIFIED` (default): no controlled content permitted. Sentinel rejects any classification marker (including legacy FOUO banners).
- `CUI`: controlled content at or below CUI is permitted, but every knowledge and inbox file must carry a frontmatter `classification` field, and files with content above UNCLASSIFIED must also carry an in-body banner (first line) matching the frontmatter value.

If `CUI`, confirm the storage tier (e.g. `ghe-cui`). The Apiary does not verify hosting — you do."

**On FOUO:** Per DoDI 5200.48, `FOUO` is an **obsolete marking** — new content must never be *created* as FOUO, so it is not offered as a ceiling choice. Legacy FOUO material is **not** automatically CUI; it must be assessed against the CUI Registry. A Hive that needs to hold received legacy FOUO should be set to the `CUI` ceiling and the individual file assessed/marked accordingly (mark it `CUI` if it qualifies, or `UNCLASSIFIED` if the Registry assessment clears it). The `FOUO` enum value is retained in the schemas only so Sentinel can *recognize and correctly handle* an inbound legacy FOUO banner (treated as CUI-equivalent), not so new Hives can adopt it as a ceiling.

Store as `{MAX_LEVEL}` (`UNCLASSIFIED` or `CUI`), `{MARKING_REQUIRED}` (true if `MAX_LEVEL` is `CUI`; false otherwise), and `{STORAGE_TIER}` (optional, documentation-only).

### Q5.7: Purpose / What Lives Here
"In one or two sentences, what knowledge *belongs* in this Hive — and what does NOT? This becomes the 'What Lives Here' section of the README, the Purpose column in the Hive Mind Registry, and the scoping signal Parliament uses to suggest re-filing mis-placed contributions to a sibling Hive."

Example: "Releasable, unclassified program knowledge for non-US-accessible teams. CUI/ITAR/SECRET+ content does NOT belong here — it lives in `vault-hive` (restricted-org)."

Store as `{HIVE_PURPOSE}`. Distinct from `{DESCRIPTION}` (a one-line summary): purpose is the contribution-scoping guidance.

### Q5.8: Federation (ask only if the user hesitates on Q5.7, or volunteers that the Hive is private)

Default both to `true` and **do not ask** — federation is the norm and an extra question on every
create is friction for no benefit. Ask only when there is a signal the Hive may not want to
participate (the user describes it as private/personal/experimental, or balks at the registry being
mentioned in Q5.7):

> "Two independent choices. Should this Hive be **listed** in the Hive Mind Registry so others can
> discover it? And should it be allowed to **suggest** that a mis-filed contribution belongs in a
> different Hive? Both default to yes."

Store as `{FEDERATION_REGISTER}` / `{FEDERATION_CROSS_HIVE}`. Emit a `federation:` block in `hive.yml`
**only if the user chose a non-default** — an absent block already means both `true`, and a redundant
block is noise in every new `hive.yml`.

**If `{FEDERATION_REGISTER}` is `false`, skip Step 6 entirely** — do not publish a row for a Hive that
just told you not to. Note it in the Step 8 summary as `registration: skipped (opted out)`. Step 7
still runs when `{FEDERATION_CROSS_HIVE}` is `true`, since an unlisted Hive can still consume the
roster.

### Q6: Knowledge Topics
"What knowledge files should this Hive start with? List the topic areas."

Example: "architecture, capabilities, infrastructure, people, decisions, integration-status"

For each topic, generate a knowledge file with scaffold frontmatter. When `{MARKING_REQUIRED}` is true, include the `classification` field with the safest default (UNCLASSIFIED — greenfield scaffolds contain no classified content). Contributors mark individual files higher as content is added:

```yaml
---
domain: {HIVE_SLUG}
type: reference
description: "{TOPIC_DESCRIPTION}"
decay: medium
confidence: low
last_updated: {DATE}
sources: []
classification: UNCLASSIFIED   # include only when hive.yml.classification.marking_required is true
---

# {TOPIC_TITLE}

(No entries yet. Contribute via `_inbox/`.)
```

### Q7: Related Agents
"Does this Hive need to delegate to any existing skills or other Hives? (optional)"

Store as `{DELEGATIONS}` — used to populate routing table in agent-definition.md.

### Q8: External References
"What external systems does this Hive's domain touch? (GHE repos, Confluence spaces, Jira boards, Slack channels, docs.meridian.example pages, Quip threads, etc.)"

Collect enough to seed the reference-library file. Don't need exhaustive coverage — the reference-library grows through contributions like any other knowledge file.

## Step 2: Generate Files

Read each template from `assets/` and substitute all `{PLACEHOLDER}` values.

**Version substitution.** `{APIARY_VERSION}` in `hive.yml.template` must be replaced with the Apiary's **current** version — read the `version` field from `{APIARY_ROOT}/.claude-plugin/plugin.json` and strip any pre-release suffix (`X.Y.Z-experimental-<alias>` → `X.Y.Z`) so it satisfies the `hive.schema.json` semver pattern. Never hardcode a version here: seeding a stale value makes the new Hive appear a major version behind and trips a spurious Upgrade on its first operate invocation.

**Registry substitutions.** Two placeholders carry federation values:
- `{HIVE_PURPOSE}` — from Q5.7. Emitted into `hive.yml` (`purpose:`), the README "What Lives Here" section, and used to build the registry row in Step 6.
- `{REGISTRY_URL}` — the canonical Hive Mind Registry page. Use **`https://confluence.meridian.example/pages/viewpage.action?pageId=100000001`** unless the user supplies a different registry. Emitted into `hive.yml` (`confluence_registry:`), the README banner, and `CLAUDE.md`.

**Classification-conditional substitutions.** Several templates carry `{CLASSIFICATION_CONSTRAINT}` / `{CLASSIFICATION_SECTION}` / `{CLASSIFICATION_SECTION_README}` placeholders, each followed by an HTML authoring-guidance comment (`<!-- Create mode substitutes … with one of: … -->`) that shows the UNCLASSIFIED and classified variants. Substitute based on the Q5.5 answer:

- If `{MAX_LEVEL}` is `UNCLASSIFIED` (or the classification block was omitted): use the UNCLASSIFIED variant from that comment. Do NOT emit a `classification:` block in `hive.yml` — leave only the commented `# classification:` *example* in `hive.yml.template` in place (it is illustrative YAML, carries no `{PLACEHOLDER}` tokens, and is safe to ship).
- If `{MAX_LEVEL}` is `CUI`: use the controlled variant. Emit the real `classification:` block in `hive.yml` with values from Q5.5. Ensure each generated knowledge-file scaffold includes the `classification: UNCLASSIFIED` frontmatter field. (`FOUO` is not a selectable ceiling — see Q5.5.)

**MANDATORY — delete authoring-guidance comments from generated files.** After substituting a `{CLASSIFICATION_*}` placeholder, **remove the entire `<!-- Create mode substitutes … -->` HTML comment block** that accompanied it. These comments contain illustrative `{MAX_LEVEL}` / `{STORAGE_TIER}` tokens; if left in place they survive into the generated `README.md`, `CLAUDE.md`, and `PROTOCOL/agent-definition.md` and will trip the Step 4 unresolved-placeholder check (and ship confusing template scaffolding to users). The rule: a generated file must contain **no `<!-- Create mode substitutes … -->` block** and **no `{CURLY_TOKEN}`** anywhere. (The `<!-- Optional … banner … -->` comment in the agent-definition template is different — keep or delete it per whether a greeting banner was provided.)

1. `hive.yml` from `assets/hive.yml.template`
2. `PROTOCOL/agent-definition.md` from `assets/agent-definition-template.md`
3. `CLAUDE.md` from `assets/child-claude-md-template.md`
4. `_custodian/config.yml` from `assets/custodian-config-template.yml`
5. `.claude/settings.json` from `assets/child-settings-template.json`
6. `README.md` from `assets/readme-template.md`
7. Knowledge files in `knowledge/` per Q6 answers (or the structure proposed in Step 0)
8. Reference library: `knowledge/reference-library.md` seeded from Q8 answers (see §Reference Library Generation below)
9. Empty directories: `_inbox/`, `_inbox/_completed/`, `_inbox/_quarantine/`, `sources/`, `sources/meeting-transcripts/`, `_metrics/`, `PROTOCOL/extensions/`, `_custodian/reports/`. Only `sources/meeting-transcripts/` is pre-created (the native-Deposit default); other doc-type subdirs (`document/`, `icd/`, `sow/`, `spec/`, `decision/`, `roster/`, `schedule/`) are created on demand by Deposit or `/extract:ingest`.
9.5. Source index: a single `sources/index.md` manifest with scaffold content:

    ```yaml
    ---
    domain: {HIVE_SLUG}
    type: source-index
    description: "Manifest of deposited sources — enables Ask to route source-answerable questions"
    decay: slow
    confidence: high
    last_updated: {DATE}
    ---
    ```

    Followed by:

    ```markdown
    # Sources

    | Date | Type | Title | Path | Participants | Key Topics |
    |------|------|-------|------|--------------|------------|

    (No deposits yet. Use the Deposit workflow for text/markdown, or `/extract:ingest` for binary documents.)
    ```

    When `{MARKING_REQUIRED}` is true, include `classification: UNCLASSIFIED` in the frontmatter.

    Do NOT LFS-track or pre-install Git LFS at create time — LFS is set up lazily by `/extract:ingest` the first time a binary document is deposited (see `protocol/sources-policy.md` § Git LFS).

10. `.gitkeep` in empty directories
11. `.gitignore` with `.DS_Store` and `settings.local.json`
12. `.circleci/config.yml` from `assets/circleci-config-template.yml` (substitute `{HIVE_SLUG}`). **Required:** a Hive repo provisioned through `meridian/owners` gets a CircleCI project that ERRORS on every PR without a config ("No configuration was found in your project"), and the org-required `ci/circleci_enterprise: gatekeeper` check needs a job named `gatekeeper` to report against. This template provides both `gatekeeper` (no-op for a content-only repo) and `inbox-size-check`.

Also generate the child Hive's thin skill for claude-clams registration:
13. Skill file from `assets/child-skill-template.md` — to be placed at the user's preferred skill location

### Reference Library Generation

Generate `knowledge/reference-library.md` from Q8 answers. The reference-library is a **thin routing index, not a content store.** It tells Ask which knowledge file to load for a given question — it must not duplicate the URLs and details that knowledge files already contain.

**Structure:**
```yaml
---
domain: {HIVE_SLUG}
type: reference-library
description: "Retrieval-trigger index for the {HIVE_NAME} Hive — routes questions to the right knowledge file or external source"
decay: medium
confidence: medium
last_updated: {DATE}
classification: UNCLASSIFIED   # include only when marking_required
---
```

**Entry rules:**
- **Default to a compact `Topic | Source | Triggers` table per `##` section** — one row per entry. It is far denser than the block form (no per-entry header/label/blank-line overhead), which is what a speculatively-loaded router wants. Reserve the block form (`### name` + `**Source:**` + `**Triggers:**` + one `**Note:**` line) for the handful of entries that need a sentence of routing context.
- **Source** points to a knowledge file and section, written **relative to `knowledge/`** in table cells (`trackers.md § Confluence`, not `knowledge/trackers.md`), not to external URLs directly. Only use direct external URLs when no knowledge file covers the topic. (Block-form `**Source:**` labels may keep the full `knowledge/…` prefix; audit resolves both.)
- **Group related resources** into a single row when they share retrieval triggers. Ten repos in one "Integration repos" row beats ten separate rows.
- **Skills & Tools** section lists skills the Hive commonly invokes, with `Install:` and `Fallback:` (columns or fields). This is the one section where direct pointers are correct — skill install info has no other canonical home.
- **Stay under 200 lines** (the audit threshold). The table format is the primary lever; convert block entries to rows before cutting coverage.

**Sources entry (mandatory on every generated reference-library):**

Every generated reference-library MUST include a Sources entry pointing to the source index. Add this row to the main table:

| Topic | Source | Triggers |
|-------|--------|----------|
| Sources | sources/index.md | meeting transcript, document, "what did we decide", "who said", ICD, spec, verbatim |

This satisfies Goal 9 (Discoverability Guarantee) — sources are reachable from Ask via the reference-library → source-index (`sources/index.md`) → source chain.

See `protocol/knowledge-schema.md` § Reference Library Entry Format for the full entry spec.

**For flat Hives** (all knowledge at `knowledge/` root): one `knowledge/reference-library.md`.
**For nested Hives** (subdirectories like `knowledge/service-catalog/`): one `reference-library.md` per subdomain, each with its own `## Scope` header.

## Step 3: Generate Signal Config

Create `.signal/config.yml`:
```yaml
slack:
  channel: "{SLACK_CHANNEL}"
```

## Step 4: Validate Rendered Output

Before summarizing, run deterministic checks on what was generated. Fail loud if any check fails — do not claim success.

1. **Schema validation** (requires `yq` + `ajv`; if absent, flag as follow-up and skip):
   ```bash
   yq -o json hive.yml | ajv validate -s {APIARY_ROOT}/skills/apiary/assets/hive.schema.json
   for f in knowledge/**/*.md; do
     yq -o json -f extract "$f" | ajv validate -s {APIARY_ROOT}/skills/apiary/assets/knowledge-entry.schema.json
   done
   ```
2. **Unresolved placeholders.** No `{CURLY_PLACEHOLDER}` tokens should remain in any generated file:
   ```bash
   if grep -rEn '\{[A-Z_]+\}' hive.yml CLAUDE.md README.md PROTOCOL/ knowledge/; then
     echo "FAIL: unresolved placeholders"
     exit 1
   fi
   ```
3. **Consistency checks.** `hive.yml.slack_channel` should match `.signal/config.yml` slack channel. `hive.yml.codeowners` CSV should match the `add-reviewer` list in `.claude/settings.json` PostToolUse hook. If `hive.yml.classification.marking_required` is true, every generated knowledge-file scaffold must include a `classification:` frontmatter field, and its value must not exceed `hive.yml.classification.max_level`.

Report each check as `PASS`/`FAIL` in the Step 8 summary.

## Step 6: Register in the Hive Mind Registry

**Skip this entire step if `{FEDERATION_REGISTER}` is `false`** (Q5.8) — record `registration: skipped (opted out)` in the Step 8 summary and move to Step 7.

Add this Hive to the canonical registry page (`{REGISTRY_URL}`, default pageId `100000001`) so it is discoverable and so other Hives learn it exists.

1. Read the current registry page storage body:
   ```bash
   confluence edit {REGISTRY_PAGE_ID}    # exports raw storage XML (a READ op despite the name)
   ```
2. Build one `<tr>` for this Hive per **`protocol/apiculturist-workflow.md` §3 "Row Markup (canonical)"** — column order, the highlighted Max Classification cell and its hexes, and the "look like the rows already there" rule all live there as the single source of truth. Insert the row alphabetically by slug into the `<tbody>`.

   A new Hive's ceiling is only ever `UNCLASSIFIED` or `CUI` (see Q5.5 — `FOUO` is obsolete and not selectable), so only the first two rows of that table apply here; the `FOUO (legacy)` row exists for Hives that predate the ban.
3. Push the update:
   ```bash
   confluence update {REGISTRY_PAGE_ID} -f <edited-file> --format storage
   ```
4. **Graceful degradation (do NOT silently skip).** If the `confluence` CLI is unavailable, unauthenticated, or returns 403/401, do not fail the whole create. Instead, print the exact `<tr>` to add and tell the user:
   > "Could not write to the registry automatically. Add this Hive to {REGISTRY_URL} manually — here is the row:" followed by the rendered `<tr>`.
   Record this as a `FAIL (manual follow-up)` in the Step 8 summary. From 2.11.0 this is also self-healing: the Apiculturist inserts the missing row on the Hive's first Parliament run.

## Step 7: Seed the Sibling Roster

Populate `hive.yml.siblings` so Parliament can route mis-filed contributions (see `protocol/custodian-workflow.md` §4.1).

1. Read the registry table (from Step 6) and extract every *other* Hive's slug, purpose, repo, and classification.
2. Write them into this Hive's `hive.yml` `siblings:` list, each as `{slug, purpose, repo, classification}`. `classification` is REQUIRED — it is the ceiling the cross-hive direction guard compares against.
3. If the registry was unreachable in Step 6, seed `siblings: []` and note it — the roster self-heals on the next Parliament run, which refreshes it from the registry (`custodian-workflow.md` §1.4). Operate mode never contacts Confluence.
4. From 2.11.0 onward the roster **and** this Hive's own row are reconciled by the Apiculturist on every Parliament run (`protocol/apiculturist-workflow.md`). Create-mode registration is the *bootstrap*, no longer the only write — so a create that degraded at Step 6.4 recovers on its own.

## Step 8: Summary

Show the user:
1. List of all generated files
2. The `hive.yml` contents
3. Step 4 validation results, plus Step 6 registry registration and Step 7 sibling-seeding results (each `PASS` / `FAIL (manual follow-up)`)
4. Next steps: "Push this repo to GHE, then register the child skill in claude-clams."
