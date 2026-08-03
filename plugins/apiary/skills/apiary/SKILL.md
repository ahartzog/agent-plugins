---
name: apiary
description: "Hive Parent Protocol (HPP) — manage Hive Mind knowledge bases. Create new Hives, run Parliament, upgrade protocols, audit health. Use when working in a Hive Mind repo (has hive.yml), or to create a new one. Triggers on 'apiary', 'hive mind', 'hive-mind', 'parliament', 'create a hive', 'hive audit'."
tools: [Glob, Grep, Read, Edit, Write, Bash, Agent, Skill, AskUserQuestion, TodoWrite]
model: opus
maxTurns: 60
---

# Apiary — Hive Parent Protocol

Upstream skill that governs all Hive Mind knowledge bases. Provides protocol, Parliament pipeline, Sentinel scanning, and learning loop enforcement. Child Hives hold only domain-specific content.

## Mode Detection

Parse the user's input to determine the mode:

- `/apiary create` or "create a hive" or "new hive mind" → **Create**
- `/apiary audit` or "audit the hive" or "hive health" → **Audit**
- `/apiary upgrade` or "upgrade the hive" → **Upgrade**
- Invoked by a child skill stub (the calling skill's `## Identity` block provides `hive_slug` and `Git remote`) → **Operate** (skip Hive Discovery — operate mode Step 0 will clone/pull the repo)
- Any other invocation from within a Hive repo (hive.yml present in cwd or parent) → **Operate**
- No hive.yml found, no child stub identity, and no explicit mode → prompt: "No Hive found. Want to create one? (`/apiary create`)"

## Hive Discovery

Before running any mode except Create:

1. **If invoked by a child skill stub:** Read `hive_slug` and `Git remote` from the calling skill's `## Identity` block. Check if `$HOME/.claude-hive/{hive_slug}/hive.yml` exists — if yes, use that as `{HIVE_ROOT}`. If not, skip discovery and proceed to operate mode Step 0 (which will clone the repo).
2. **Otherwise:** Check current working directory for `hive.yml`, walk up parent directories.
3. If found → store path as `{HIVE_ROOT}`, read `hive.yml` for identity
4. If not found → prompt to create

## Version Check (automatic, every invocation)

After discovering `hive.yml`, compare `upstream_version` against this skill's current version, read from `${CLAUDE_PLUGIN_ROOT}/.claude-plugin/plugin.json`. If major version mismatch → run Upgrade mode automatically before proceeding. If minor/patch mismatch → no action needed (protocol improvements are already live).

`${CLAUDE_PLUGIN_ROOT}` is the plugin root — the directory holding both `.claude-plugin/` and `skills/`. Use it directly here; this step runs *before* `{APIARY_ROOT}` is resolved below, and a path relative to this file (`../.claude-plugin/`) resolves to `skills/.claude-plugin/`, which does not exist.

## Mode Execution

Resolve `{APIARY_ROOT}` = `${CLAUDE_PLUGIN_ROOT}` now, as a literal absolute path — mode files below use it as a placeholder. `${CLAUDE_PLUGIN_ROOT}` only substitutes in this file's own content, not in files loaded later via Read, so carry the resolved value forward whenever a mode file's instructions reference `{APIARY_ROOT}`.

### Create Mode

Read `references/mode-create.md` and follow its instructions.

### Operate Mode

Read `references/mode-operate.md` and follow its instructions.

### Upgrade Mode

Read `references/mode-upgrade.md` and follow its instructions.

### Audit Mode

Read `references/mode-audit.md` and follow its instructions.

## Protocol Files

This skill bundles canonical protocol files in `protocol/`. These are the single source of truth for all Hive governance:

- `protocol/design-goals.md` — North star principles (MUST be consulted before any protocol change — see CONTRIBUTING.md)
- `protocol/triage-policy.md` — Contribution routing (fast path vs. deliberation)
- `protocol/security-policy.md` — CUI defense-in-depth, PII, injection defense
- `protocol/operational-model.md` — Three-phase session→accumulation→incorporation loop
- `protocol/learning-loops.md` — Four feedback circuits — compact operational rules (see operate mode Step 2 for when to load)
- `protocol/workflows.md` — Interaction modes
- `protocol/knowledge-schema.md` — Required frontmatter schema for knowledge files (prose companion to `assets/knowledge-entry.schema.json`)
- `protocol/routing-protocol.md` — Canonical Reference Library Discovery Protocol (question → knowledge routing). Upstream-owned; child personas reference it rather than restating it.
- `protocol/tool-tiers.md` — Three-tier tool-availability model; graceful degradation when skills/MCPs are missing
- `protocol/ethical-guidelines.md` — Ethical constraints (DRAFT)
- `protocol/custodian-workflow.md` — Parliament runbook including Sentinel
- `protocol/sensitive-data-patterns.md` — Source of truth for PII / credential patterns; shared by pre-push scrub (operate mode) and Parliament Sentinel
- `protocol/ways-of-working.md` — Recurring structural patterns across Hives (e.g., people directory layout)
- `protocol/sources-policy.md` — Deposit path for primary source material (transcripts, documents); Sentinel-gated, no Parliament deliberation
- `protocol/document-quality.md` — `doc_type` / `authority` / `covers` taxonomy for external-document catalogs; trawling heuristics; question-type routing
- `protocol/external-search-agent.md` — Dispatch contract for the RLDP §Search live store-search subagent

## Machine-Readable Schemas

In `assets/`:

- `hive.schema.json` — JSON Schema for `hive.yml` (identity contract)
- `inbox-entry.schema.json` — JSON Schema for `_inbox/*.md` frontmatter (Sentinel rejects files that fail this)
- `knowledge-entry.schema.json` — JSON Schema for `knowledge/**/*.md` frontmatter (Archivist validates on merge)
- `source-entry.schema.json` — JSON Schema for `sources/**/*.md` frontmatter (Sentinel validates on deposit)
- `workflow-extension.schema.json` — JSON Schema for workflow-extension frontmatter (Audit Step 5 validates; authoring guide: `references/authoring-workflow-extensions.md`)
- `gate-extension.schema.json` — JSON Schema for gate-extension frontmatter: Hive-specific pre-push hardening layers baked into the generated hook, additive to the Sentinel and structurally unable to suppress it (Audit Step 5 validates; authoring guide: `references/authoring-gate-extensions.md`)
- `sentinel-patterns.json` — Runtime source of truth for credential / PII regex patterns. Read by both the pre-push hook and Parliament Sentinel.
- `generate-hook.sh` — Generator script (Bash + jq). Reads `sentinel-patterns.json` and emits a self-contained bash pre-push hook to stdout. Run by operate-mode Step 0 as `generate-hook.sh <patterns.json> [HIVE_ROOT]`; passing `HIVE_ROOT` also bakes in that Hive's `extensions.gates`. The generated hook supports CLI modes: `pre-push scan FILE...` or `pre-push scan-dir HIVE_ROOT` (neither runs gate extensions — those fire only on the actual push path, to avoid recursion when a gate itself calls `scan`).

Validate with `yq -o json <file> | ajv validate -s <schema>`. Create mode Step 4 runs these checks automatically.

## Skill Knowledge

The Apiary knows that Meridian Systems shared skills live in claude-clams. When a Hive's agent-definition routes to external skills (e.g., `/platform`, `/cyber-accreditation`), the Apiary understands the invocation pattern but defers domain-specific skill relevance to each Hive's routing table.

## Notes

- This SKILL.md is a thin router. All substance lives in `references/` and `protocol/`.
- **The Apiary plugin is a hard dependency for all child Hives.** Child skills declare `apiary` in their `plugin.json` dependencies. Protocol files are read directly from this skill's `protocol/` directory at runtime — no vendoring or syncing required.
- All git flow (clone, pull, sync, rebase-before-push) is handled by operate mode, not by hooks. This ensures operations work regardless of where the user invoked the skill from.
- Sentinel cannot be disabled. It runs on every Parliament pipeline.
