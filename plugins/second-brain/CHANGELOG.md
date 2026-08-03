# Changelog

All notable changes to the **second-brain** plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this plugin uses [Semantic Versioning](https://semver.org/). The version at the top of each release must match `.claude-plugin/plugin.json`. See the repo-level [CONTRIBUTING.md](../../CONTRIBUTING.md) for what counts as a change and how to pick a bump level.

## [2.1.0] — 2026-08-03

### Added
- **New optional inline annotation `[effective: YYYY-MM-DD]`** in `protocol/knowledge-schema.md` — when a fact became true **in the world**, as distinct from `[learned:]` (when it entered the knowledge base). The two clocks diverge exactly where it hurts: a fact backfilled today about something that changed last quarter is the newest by `[learned:]` and the oldest in reality, so "the most recent fact" returns the wrong answer confidently; and a fact written months ago that is still true reads as stale and gets displaced by something newer but less accurate. Optional by construction — existing facts carry none and behave exactly as before, so nothing needs backfilling and no file becomes invalid. Never inferred: if the source does not state the world-validity date, leave it off.

  Added under the **shared-taxonomy contract** with the Apiary (`plugins/apiary` 2.24.0), where the same annotation lands in the same release; the definition is deliberately identical. The consumers differ and the schema says so: the Apiary additionally ranks retrieval candidates on it (its RLDP §Prefer) and decays audit findings from it — mechanics a single-user Second Brain has no counterpart for. Here it serves answer ranking and staleness judgment.

## [2.0.1] — 2026-08-03

### Changed
- Marketplace renamed `ahartzog-skills` → `ahartzog`; install pointers emitted by this plugin updated accordingly (`references/mode-create.md`, `references/migration.md`, `references/maturity-model.md`, `assets/hub-template.md`, `assets/domain-claude-md-template.md`). No behavior change.

## [2.0.0] — 2026-07-30

Architectural release: the operating protocol is now **single-sourced in the skill and loaded, never copied**. Cross-pollinated from a sibling fork of this plugin (which pioneered operate mode), merged with this line's five-loop model. Hubs built against 1.x keep working but should migrate (`references/migration.md`); the reference hub migration was applied the same day.

### Added
- **Operate mode** (`references/mode-operate.md`, `/second-brain operate`) — loads the protocol layer (learning loops + Self-Awareness Protocol, triage policy, knowledge schema) into the session, resolves `auto_contribute` from the *invoking agent's* frontmatter (subagents resolve their own — gates are never inherited), reads local extensions (hub/domain `CLAUDE.md`, `CONTRIBUTING.md`, `custodian-workflow.md`), and confirms in two lines. Agent definitions bootstrap it as their first action via a `## Bootstrapping` block (now in `assets/agent-template.md`) with a fail-visible contract: skill missing → read freely, write nothing, never reconstruct triage from memory.
- **Migration guide** (`references/migration.md`) — diagnose and upgrade pre-2.0 hubs: add the bootstrap, sort `CLAUDE.md` content into protocol/agent-behavior/local buckets, strip duplicated rules from agent files, verify from outside the hub. Ordering rule: bootstrap lands before stripping, and never strip until the installed skill serves operate mode.
- **Domain CLAUDE.md template** (`assets/domain-claude-md-template.md`) — thin signpost for self-contained/externally-shared domain folders: entry-point pointer, ambient guardrails (≤5), contents table, skill-prerequisite Dependencies section.
- **Transcript-based wrap pipeline** (`scripts/extract_session.py` + rewritten `references/mode-wrap.md`) — wrap now parses the session JSONL (`~/.claude/projects/<slug>/`), which survives context compaction, and delegates the mechanical harvest/diff to a Sonnet subagent fed the digest; judgment, the Loop E gate, telemetry, and `.session-gate` stay inline. Replaces 1.3.0's never-fork constraint, whose premise (an isolated context can't see the session) the digest defuses. Adds a digest sanity check and runs the extractor against the session's own cwd — deliberately *not* `--cwd {hub}`, which can silently pick up the wrong conversation when wrap is invoked via a shim.
- **`[decided:]` epistemic provenance expansion** (`protocol/knowledge-schema.md`) — `<who>` may now be a human name or an agent id; decision-vs-inference line, ratification-candidate semantics for agent decisions, who+date as one unit, never-backfill, household worked example. Human decisions keep the 1.2.0 quote-test bar.
- **Reference-library table format** (`protocol/knowledge-schema.md`) — compact `Topic | Source | Triggers` table is now the default entry format (block form demoted to escape hatch); 200-line size cap.
- **Plugin-level `CONTRIBUTING.md`** — apiary schema cross-check table ("I didn't check" is not acceptable), hot-path budgets, protocol-blast-radius warning. Records known second-brain↔apiary schema drift as of 2026-07-30.

### Changed
- **`protocol/learning-loops.md`** now carries the full Self-Awareness Protocol (continuous contribution reflex + task-completion gate, with the Loop E questions as a gate step) — it defines both WHEN and HOW, and agent files no longer restate any of it. The session-start warm-up scan is **removed**: freshness inventory is an audit/custodian job, not a per-session hot-path cost.
- **`assets/agent-template.md`** — adds the `## Bootstrapping` block; drops the `## Self-Awareness Protocol` section and the universal rules (temporal annotations, supersede, Contribution Gate) now loaded via operate mode; Rules section is domain-rules-only with an explicit no-restatement preamble; Reference Library Discovery updated for the table format, recursion, and contributor drop-ins.
- **`assets/hub-template.md`** — protocol restatement replaced by "Operating Protocol — Loaded, Not Restated" (copies freeze; CLAUDE.md doesn't reliably load on file-path/shim invocation) with precedence chain and an Ambient Guardrails section; Global Rules trimmed to genuinely ambient/local items; Knowledge Maintenance how-to replaced by Local Knowledge Policy (size budgets, archive, what-not-to-update, content-vs-instructions); Process Maintenance and Learning Loops summary sections removed (protocol); adds the 5-rung invocation ladder ending in "every path converges on reading the agent definition."
- **`SKILL.md`** — Operate is mode #1; Protocol Layer section rewritten around single-sourcing and the agent-definition-as-enforcement-point argument; principle 8 replaced ("The CLAUDE.md is the operating system" → "The skill owns the protocol; the agent definition enforces it; CLAUDE.md owns what's local"); principle 10 "Three phases, always" → "Both phases, always" (warm-up removed from the hot path).
- **`DESIGN-GOALS.md`** — Goal 3 rewritten to the enforcement-point position (with the empirical caveat that Claude Code's lazy CLAUDE.md attachment softens but does not license the old design); Goal 6 gains hot-path budgets (mode-operate ~70 lines; learning-loops ≤ ~180) and the protocol-vs-audit rule of thumb.
- Mode references (`mode-create`, `mode-adopt`, `mode-improve`, `mode-audit`, `maturity-model`, `references/learning-loops.md`, `references/framework.md`, `references/workflow-patterns.md`, `assets/contribution-agent-prompt.md`, README) updated for the new architecture: create/adopt install the bootstrap instead of copying `protocol/` into hubs; audit gains Operate-Mode Bootstrap (Critical), Protocol Duplication, and Unratified Agent Decisions checks plus dual-format reference-library validation and the 200-line cap; improve gains the migration path (with a scan-for-embedded-domain-content step before deleting restated sections); framework reframes the hub as router + shared context; workflow pattern #10 becomes the transcript pipeline; the legacy contribution-subagent prompt takes protocol content inline (five loops) instead of reading hub protocol/ copies.

### Removed
- Per-hub `protocol/` copies (create/adopt no longer generate them; migration deletes them once bootstraps land).
- The agent-file `## Self-Awareness Protocol` restatement and Contribution Gate rule (loaded via operate mode instead).
- The session-start warm-up scan (freshness moved to audit; see Changed).

## [1.3.0] — 2026-07-21

### Added
- **Wrap mode** (`references/mode-wrap.md`, `/second-brain wrap`) — session-end verification net. Diffs the live conversation against the hub's knowledge files into a Captured/Missing/Ambiguous ledger, persists gaps per `auto_contribute`, runs the four Loop E retrospection questions, appends `run_type: "session-end"` telemetry to `_reports/loop-health.json`, and touches `.session-gate` (the forward contract for conditional Stop-hook enforcement). Runs inline only — never forked, since an isolated context cannot see the session being wrapped; refuses with "nothing to verify" in a fresh session rather than fabricating a ledger. Offers a two-keystroke alias shim (`/wrap`) on first run in a hub. Proven in a production vault before promotion.
- **Session-End Wrap pattern** (`references/workflow-patterns.md` #10; README catalog now ten patterns).

### Fixed
- Removed inert SKILL.md frontmatter fields `tools:` and `maxTurns:` — neither is a valid skill field (per Claude Code skills docs); both were silently ignored. `model: opus` is valid and retained.

## [1.2.0] — 2026-07-12

### Added
- **Audit Safety Constraints** (`mode-audit.md`) — six incident-derived, non-negotiable rules for any audit/cleanup/fix: never delete (flag for the human), never edit inside code fences, don't touch escaped table pipes, no absence claims from sampled searches, split commits by author, and never bulk-shorten wiki-links. `mode-improve.md` now references them (it applies fixes, so they bind hardest there).
- **Wiki-Link Integrity check** (`mode-audit.md`, Obsidian vaults only) — flags bare `[[Name]]` links whose basename is ambiguous vault-wide; these resolve to the wrong note silently, invisible to a dead-link check.
- **Provenance marker** `[decided: NAME, YYYY-MM-DD]` (`knowledge-schema.md`, `agent-template.md`) — distinguishes a genuine human decision from default agent synthesis. Sparse, quote-test-gated, never backfilled.
- **Pre-push sentinel** (`assets/sentinel-patterns.json`, `assets/pre-push-sentinel.sh`, `enforcement-hooks.md` recipe 4) — a fail-open git pre-push hook that blocks credential/PII leaks for vaults that auto-push on a timer. Portable, single-source-of-truth patterns, `SENTINEL_SKIP=1` bypass, SessionStart self-install (git hooks aren't versioned). Single-operator sibling to apiary's Parliament-scoped sentinel.

## [1.1.0] — 2026-07-12

### Added
- README **"Under the Hood: The Techniques"** section — documents the index/navigation-layer model (retrieval triggers, per-layer size budgets), the knowledge-file metadata schema (`type`/`decay`/`confidence`), the two-kinds-of-staleness model (knowledge decay vs. sync drift via `.staleness-manifest.json`), inline provenance annotations, the three-tier memory taxonomy, and the "why not just use memory" (compaction / dual-write) rationale.
- README **"Workflow Patterns"** section surfacing the nine-pattern catalog.
- Embedded the persona and flywheel diagrams (`assets/*.svg`) in the README.
- MIT `LICENSE` and a `license` field in `plugin.json` — the plugin is now shareable with attribution preserved.

### Fixed
- `mode-audit` drift (B1–B3) surfaced by a hardening review — audit checks realigned with the current knowledge schema and maturity model.

## [1.0.0] — 2026-06-10

Initial release.

### Added
- **Five learning loops (A–E).** Loop E (process retrospection → agent definitions) is the signature addition: proactive self-review of the agent's own instructions at every task-completion gate, with an eviction discipline for dead rules — not just reactive correction capture.
- **Adopt mode** — bring existing hand-rolled agents under management without rewriting them (voice-preserving).
- Create / audit / improve / add-workflow modes.
- Principles-over-procedures agent template with worked examples and slimmed rules.
- Knowledge-file schema (`protocol/knowledge-schema.md`): `type`/`decay`/`confidence` frontmatter, inline temporal annotations, and mechanical staleness detection via `.staleness-manifest.json`.
- Golden-question evals and hook-based enforcement references.
- Personal content-source catalog (Monarch, Google Workspace, MyChart, Apple Health).
