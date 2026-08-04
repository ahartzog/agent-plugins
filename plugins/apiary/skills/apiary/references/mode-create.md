# Create Mode — New Hive Scaffolding

This document guides the Create mode of the Apiary skill. Follow these steps exactly.

## Prerequisites

SKILL.md has already confirmed: no `hive.yml` found in cwd (or user explicitly requested create).

## Step 0: Source Material Audit (BEFORE interviewing)

Before Step 1, ask: **"Is there existing content this Hive should be seeded from? This could be a personal Second Brain, a doc corpus, a set of Confluence pages, or nothing (greenfield)."**

If the user points to an existing corpus:

1. **Read the corpus before interviewing.** Key fields (name, description, codeowners, knowledge topics) can often be inferred — do NOT ask questions the corpus already answers.
2. **Ask for sanitization directives explicitly.** The corpus may contain material unsafe for a shared Hive:
   - Personal editorial commentary about named individuals → strip to role + contact only
   - Sensitivity markers (confidential, internal-only, proprietary, `[INTERNAL]` flags) → reference by path; never reproduce
   - Local filesystem paths (OneDrive, vault, home dir) → map to canonical URLs (SharePoint, GitHub Enterprise (GHE), Confluence); mark unconfirmed URLs as `{path TBD}`
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

Example: "Widget Integration Sherpa — helps Widget and Acme engineers understand each other's systems and track integration progress."

Store as `{PERSONA_NAME}` and `{SCOPE_SENTENCE}`.

### Q4: Codeowners
"Who should approve protocol changes and handle escalations? (GitHub usernames, comma-separated)"

Store as `{CODEOWNERS}` (array) and `{CODEOWNERS_CSV}` (comma string).

### Q5.25: Git Remote
"What is the remote URL for this Hive's repo on your git host? (e.g. `git@github.example.com:your-org/my-hive.git`)"

Store as `{GIT_REMOTE}`.

### Q5.3: Default Branch
"What is the default branch name? (default: `master`)"

Store as `{DEFAULT_BRANCH}`. Default to `master` if the user skips.

### Q5.35: Inbox Transport
"How should inbox contributions travel? (default: `branch` — the queue-branch transport)

- `branch` (default): sessions push inbox entries to a dedicated queue branch (default name `inbox`) that is never PR-gated, and `{DEFAULT_BRANCH}` can carry full vanilla protection — required PR + codeowner review on everything. Unreviewed content never enters default-branch history directly, and capture friction is identical (one direct push).
- `default-branch` (legacy): sessions push inbox entries straight to `{DEFAULT_BRANCH}`. Choose this only if you specifically want inbox commits in default-branch history, or must match the fleet's pre-2.23.0 behavior."

Store as `{INBOX_TRANSPORT}`. Default to `branch` if the user skips — the template already carries
`inbox_transport: branch` / `inbox_branch: inbox`, so the default needs no edit. Ask for a queue
branch name only if the user wants a non-default one → `{INBOX_BRANCH}` (edit the template's
`inbox_branch:` line). If the user chooses `default-branch`, **delete both lines** from the
generated `hive.yml` — an absent field means `default-branch`, which is also the compatibility
semantics every pre-2.23.0 Hive keeps (the recommended-default applies to *new* Hives only; the
runtime never flips an existing Hive whose `hive.yml` is silent).

Under `branch` (the default): tell the user the queue branch is bootstrapped automatically on the
first session push, and that after scaffolding they should (1) apply vanilla branch protection to
`{DEFAULT_BRANCH}`, (2) add a deletion/force-push-only ruleset on `{INBOX_BRANCH}`, and (3) set
`parliament_push_mode: pr` **once the protection is on** (not before — `pr` mode on an
unprotected branch strands PRs; audit Step 4b checks the pairing) — per
`protocol/security-policy.md` § Repository Protection Model (transport=branch variant). Create
mode does not configure repo-side protection; record these as manual follow-ups in the Step 4
summary. The transport works unprotected in the meantime — audit reports the unrealized
protection goal as a WARN until step (1) is done.

### Q5.7: Purpose / What Lives Here
"In one or two sentences, what knowledge *belongs* in this Hive — and what does NOT? This becomes the 'What Lives Here' section of the README and the scoping signal contributors and Parliament use to keep contributions on-topic."

Example: "Platform runtime and deployment knowledge for the services team.
Customer contract terms and pricing do NOT belong here — those live with Legal."

Store as `{HIVE_PURPOSE}`. Distinct from `{DESCRIPTION}` (a one-line summary): purpose is the contribution-scoping guidance.

### Q6: Knowledge Topics
"What knowledge files should this Hive start with? List the topic areas."

Example: "architecture, capabilities, infrastructure, people, decisions, integration-status"

For each topic, generate a knowledge file with scaffold frontmatter:

```yaml
---
domain: {HIVE_SLUG}
type: reference
description: "{TOPIC_DESCRIPTION}"
decay: medium
confidence: low
last_updated: {DATE}
sources: []
---

# {TOPIC_TITLE}

(No entries yet. Contribute via `_inbox/`.)
```

### Q7: Related Agents
"Does this Hive need to delegate to any existing skills or other Hives? (optional)"

Store as `{DELEGATIONS}` — used to populate routing table in agent-definition.md.

### Q8: External References
"What external systems does this Hive's domain touch? (git host repos, Confluence spaces, Jira boards, Slack channels, internal docs pages, Quip threads, etc.)"

Collect enough to seed the reference-library file. Don't need exhaustive coverage — the reference-library grows through contributions like any other knowledge file.

## Step 2: Generate Files

Read each template from `assets/` and substitute all `{PLACEHOLDER}` values.

**Version substitution.** `{APIARY_VERSION}` in `hive.yml.template` must be replaced with the Apiary's **current** version — read the `version` field from `{APIARY_ROOT}/.claude-plugin/plugin.json` and strip any pre-release suffix (`X.Y.Z-experimental-<alias>` → `X.Y.Z`) so it satisfies the `hive.schema.json` semver pattern. Never hardcode a version here: seeding a stale value makes the new Hive appear a major version behind and trips a spurious Upgrade on its first operate invocation.

**Purpose substitution.** `{HIVE_PURPOSE}` — from Q5.7. Emitted into `hive.yml` (`purpose:`) and the README "What Lives Here" section.

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

    Do NOT LFS-track or pre-install Git LFS at create time — LFS is set up lazily by `/extract:ingest` the first time a binary document is deposited (see `protocol/sources-policy.md` § Git LFS).

10. `.gitkeep` in empty directories
11. `.gitignore` with `.DS_Store`, `settings.local.json`, `.parliament/`, and `.inbox-worktree/` (the last two keep the Parliament clone and the queue-push worktree — both living inside the session clone — out of any broad `git add`, e.g. Orphaned Branch Recovery's)
12. `.circleci/config.yml` from `assets/circleci-config-template.yml` (substitute `{HIVE_SLUG}`). **Required if the Hive repo is built on CircleCI:** a repo with no config ERRORS on every PR ("No configuration was found in your project"), and if your org enforces a required status check under a specific job name, this template provides a no-op `gatekeeper` job to satisfy it, alongside `inbox-size-check`.

Also generate the child Hive's thin skill so `/{HIVE_SLUG}` becomes callable:
13. Skill file from `assets/child-skill-template.md` — for personal use, place it in `~/.claude/skills/`; to share it with a team, publish it via a plugin marketplace instead

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

## Step 3: Validate Rendered Output

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
3. **Consistency checks.** `hive.yml.codeowners` CSV should match the `add-reviewer` list in `.claude/settings.json` PostToolUse hook.

Report each check as `PASS`/`FAIL` in the Step 4 summary.

## Step 4: Summary

Show the user:
1. List of all generated files
2. The `hive.yml` contents
3. Step 3 validation results
4. Next steps: "Push this repo to your git host. Then make the generated skill callable: drop it in `~/.claude/skills/` for immediate personal use, or publish it via a plugin marketplace to share it with a team."
