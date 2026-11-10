# Changelog

All notable changes to the **second-brain** plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this plugin uses [Semantic Versioning](https://semver.org/). The version at the top of each release must match `.claude-plugin/plugin.json`. See the repo-level [CONTRIBUTING.md](../../CONTRIBUTING.md) for what counts as a change and how to pick a bump level.

## [3.0.0] — 2026-11-09

The in-session protocol is replaced. Operate mode now loads one file, `protocol/operating-protocol.md` (about 9.5KB), where 2.x loaded three protocol files plus the hub's custodian workflow (about 45KB). The change came out of a 30-day audit of real sessions and thirteen scripted head-to-head runs. Token cost was not the driver; on a heavy scenario both protocols cost the same. The driver was behavior: under the new protocol a knowledge base grew a third to a half as much for the same events, copied values turned into links to one owner, no task dates were invented, every write was reported, and nothing was queued for approval somewhere the owner had to go and look.

**Do you need to do anything?** Agent definitions do not change: the Bootstrapping block and `Skill(second-brain)` "operate" work as before. Three things in an existing hub are worth a look after pulling: (1) any local `CLAUDE.md` line that restates "changed facts get `[superseded:]`" is now stale under git and should be reworded or removed; (2) if your hub is a git repository, sessions will start committing their own writes with descriptive messages; (3) open checkbox tasks that agents wrote as suggestions, with dates nobody set, no longer match the protocol and can be triaged.

### Added
- **`protocol/operating-protocol.md`** — the whole in-session protocol in one file, with reasons attached to rules. New concepts: three kinds of content (state, log, analysis) that are written and trusted differently; `[verified: date, source]` for when a fact was last checked against the world; a `Saved:` line for every write; per-write commits under git; vault-wide propagation of a corrected fact, with copies replaced by links to one owner; a second read by a fresh subagent on figures that feed irreversible actions; commitments versus suggestions (only a commitment becomes a dated task); project status blocks for multi-day efforts; a stricter folder rule beats the protocol.
- **`tests/protocol-scenarios.md`** — a regression set of three scripted conversations (17 turns) with expected behavior, what to measure from the diff, and how to run it. All particulars are invented.
- **`[verified:]`** in `protocol/knowledge-schema.md` § Inline Annotations.

### Changed
- **Supersession.** Under git, a changed fact replaces the old value; old, new and reason go in the reply and the commit message. Inline `[superseded:]` is kept only where the old value is still in circulation. Without git, inline `[superseded:]` remains the rule.
- **`references/mode-operate.md`** — loads one file, no longer reads `custodian-workflow.md`, and no longer prints a "Protocol loaded" line. Asked directly, an agent reports the protocol date and its `auto_contribute` value.
- **`auto_contribute: false`** — a log entry the owner dictates is written directly. Everything else is still proposed, as one numbered list rather than one prompt per item.
- **Links (`[edge]`)** move from always-prompt to write. A link is additive and easy to remove.
- **Agent-file changes** are proposed as numbered items in the reply and applied in the session on a yes. The four retrospection questions and the per-loop prompt template are gone.
- **`protocol/triage-policy.md`** and **`protocol/learning-loops.md`** — rewritten as short demand-loaded references: the two-class write/ask rule with the tag vocabulary, and the five loop names mapped to the operating protocol. Loop telemetry now counts outcomes (facts the owner corrected, save checks requested, deadlines missed).
- **`SKILL.md`** — Protocol Layer and Key Principles sections rewritten to match.
- **`assets/agent-template.md`** — the bootstrap fallback now lets an agent without the skill write what the owner explicitly dictates; it previously wrote nothing.
- **`DESIGN-GOALS.md`** — protocol-size guidance and the contributor test step updated for the single file.
- Examples in `protocol/knowledge-schema.md` made generic.

### Removed
- The Self-Awareness Protocol's task-completion gate, the session-end report, the "fresh-session test", and the requirement that sessions write `loop-health.json`. Capture is continuous and reported per write.

### Known follow-ups
- Create, adopt, audit, improve, add-workflow and wrap still describe in-session behavior in 2.x terms in places (decay tiers, the "Protocol loaded: 5 loops" check in migration and audit text, edges as always-prompt in wrap). `SKILL.md` states that the operating protocol wins where they differ. Reconciling those files is a later release.
- `references/learning-loops.md` (design rationale) describes the 2.x mechanics.

## [2.2.1] — 2026-11-01

Bug fixes from an external review (GitHub issues #9, #10, #11 plus four privately reported sentinel gaps). Nothing here changes an agent file or a knowledge schema; pull and the fixed scripts and hook are in effect. If you installed the pre-push sentinel into a vault, re-copy `assets/pre-push-sentinel.sh` and `assets/sentinel-patterns.json` into the vault's `.claude/hooks/` — the hook is a copy, not a link, and the old copy keeps the gaps below.

### Fixed
- **`scripts/extract_session.py`** — the project slug replaced only `/` and `.`, but Claude Code hyphenates every non-alphanumeric character. A hub under a path with an underscore or a space (`~/my_vault`, `~/Second Brain`) looked up a folder that does not exist, `find_transcript` returned None, and `/second-brain wrap` reported a session that did real work as fresh (#9).
- **`scripts/link_inert_refs.py`** — `--apply` rewrote the text of links that already worked: ``[`foo.md`](area/foo.md)`` became a nested, broken wikilink, and `[see foo.md](...)` likewise. Existing `[text](target)` and `[[target|alias]]` spans now pass through untouched; only the text between them is converted (#10).
- **`scripts/link_inert_refs.py`** — a prose reference that began with a capital ("See foo.md") came out as "see [[...]]". The author's own word and spacing are kept (#10).
- **`scripts/link_inert_refs.py`** — a path-qualified reference matched on a bare string suffix with no folder boundary and took the first sorted candidate, so `` `ops/notes.md` `` could silently link to `devops/notes` or always to `a/ops/notes` when `b/ops/notes` also existed. The match is now on a folder boundary, an exact path wins, a single match converts, and several matches are refused and listed under "need a human decision" like an ambiguous bare filename (#11).
- **`assets/pre-push-sentinel.sh`** — a branch pushed for the first time scanned only its tip commit; a ten-commit branch shipped nine commits unscanned. The range is now `$local_sha --not --remotes`.
- **`assets/pre-push-sentinel.sh`** — when `git log` failed (remote sha not in this clone, shallow clone) the empty diff was scanned and the push passed as clean. That case now blocks with a message; `SENTINEL_SKIP=1` still bypasses. Fail-open remains for a missing pattern file or missing python.
- **`assets/sentinel-patterns.json`** — `connection-string-with-password` required a user segment, so the common `redis://:password@host` form was never matched.

### Added
- **`scripts/test_scripts.py`** — fixture tests for both scripts (17 cases), including one for each bug above. Run with `python3 -I plugins/second-brain/skills/second-brain/scripts/test_scripts.py`.
- **`tests/pre-push-sentinel.test.sh`** — exercises the hook against a local bare remote: multi-commit first push, incremental push, the Redis form, the unknown-remote-sha block, and the bypass.

## [2.2.0] — 2026-09-08

Absorbs the link-graph work from the work-edition lineage (0.6.0–0.8.0), taken as a subset rather than a merge. Everything here is additive: no agent file needs editing, the Bootstrapping block and `auto_contribute` gate are unchanged, and no personal-edition feature was replaced.

### Added
- **`protocol/link-authoring.md`** — link grammar for knowledge-file cross-references, demand-loaded (Operate mode does not read it). Two link forms with the rule that they are not interchangeable addresses; mandatory path qualification at write time; the two escaping cases that break links silently (table-cell alias pipes, anchors ending in `]`); the three-way breakdown of how renames and moves break inbound links; three relation senses (`defined-by`, `depends-on`, `superseded-by`) and no more; anchor-level selection keyed to the target's `decay`; placement at the mention rather than in a bottom-of-file `## Related` list; the opt-in `## Adjacent Domains` table for cross-domain seams; and the rule that adding an inbound link into a domain you don't own is a proposal, not a write.
- **`references/link-graph.md`** — the rationale, including the objections. An agent does not click links, so clickability buys nothing for retrieval; what survives that objection is authority direction, anchor economics, and human navigation. Whether links improve agent *answer quality* over inert backtick references is explicitly unmeasured and labeled as such. Also records why this is a Loop B sub-block rather than a sixth loop, why the topology is a star and not a clique, and why edge count is never graded.
- **`scripts/link_inert_refs.py`** — converts inert filename references into real links. Dry-run by default, `--apply` writes, ambiguous basenames are refused and listed for a human. Skips frontmatter, code fences, and `_reports`/`_archive`/`_Templates`.
- **Loop B § Connections** in `protocol/learning-loops.md` — the in-session trigger for link creation. A connection is a second unit of knowledge and fires even in sessions that learned no new fact: if you opened a second file to answer, that traversal is the edge. Two files claiming authority over the same content is the disqualifier — that is `[architecture]` and the fix is consolidation.
- **`[edge]` triage category** (always-prompt, in both `protocol/triage-policy.md` and the `protocol/learning-loops.md` routing table). Always-prompt because traversal is evidence, not proof: a hop taken because routing was bad is not a relationship.
- **`[agent-revision]` triage category** (always-prompt) — the Loop E contribution class, formally separated from `[process]`, which sheds its Loop E label accordingly.
- **`references/mode-audit.md` § Link Graph Health** — measures degree in the lateral graph, which every existing structural check misses: a file the agent routes to, referenced by nothing and referencing nothing, passes them all. Counts inert references, broken targets, broken anchors, anchors into fast-decay files, in-degree-zero orphans, and cross-domain edges (reported, never graded). Includes the co-occurrence sweep as candidate generation, and the `\|` table-alias trap that manufactures false orphans.
- **`references/mode-audit.md` § Behavioral Rules in CLAUDE.md** (L2+) — the audited form of principle 8. A `CLAUDE.md` does not reliably load on slash-command or skill-wrapper invocation, so behavioral rules living only there are unenforced for most invocations.
- **`references/mode-audit.md` § Sensitive-Store Leak** — for hubs with a confidentiality-scoped domain, checks that nothing outside it links or path-references in. Adapted from the work edition's people-store framing to cover clearance-scoped folders and agents under a confidentiality rule that survives their contribution gate.
- **`covers` field** in `references/document-quality.md`, adopted from the Apiary rendering under the shared-taxonomy contract. `doc_type` and `authority` say what class a document is and how far to trust it; neither says what is inside it. A catalog row whose only free text is a filename can be matched only by filename.
- **`--read-manifest [HUB_PATH]`** on `scripts/extract_session.py`, and the **Connections bucket** it feeds in `references/mode-wrap.md`. The digest strips tool traffic, so which files a session opened is otherwise invisible. Deliberately partial: `Read`/`Edit`/`Write` only, so a thin manifest is thin evidence rather than proof nothing was traversed.

### Changed
- **`references/maturity-model.md`** L3 now requires knowledge files to link to each other, not just to the agent — "Connected" previously graded only the routing tree. L4 adds link-graph soundness (zero broken targets and anchors, no orphans). L5 adds landed Loop E revisions and consolidated duplicate authority, with the direction stated explicitly: that level is evidenced by edge count going *down*. The ladder change ships in the same release as the audit check on purpose; porting the check alone would grade something maturity did not require.
- **`references/mode-audit.md` § Process Retrospection (Loop E)** now reads `_reports/loop-health.json` telemetry rather than inferring from git log alone. It accepts `run_type: "wrap"` **and** `run_type: "session-end"` — wrap writes the latter and existing telemetry carries it, so a check keyed to one value would report a silent false negative. Existing telemetry is not rewritten.
- **`protocol/knowledge-schema.md`** gains a Cross-References section naming inert references as a defect class and pointing at the link grammar.

### Fixed
- `scripts/link_inert_refs.py` docstring claimed "0 clean, 1 nothing to do"; the code returns 0 when conversions were *found* and 1 when there were none. Corrected in the docstring, with the polarity called out — carry this back to the work edition, where the defect originated.

### Deliberately not taken
- **RLDP / `routing-protocol.md` / `tool-tiers.md`.** Three-way divergence: the personal edition has none, the work export is dated 2026-07-30, and `plugins/apiary` carries a newer 2026-08-03 rendering. Porting the work copy would put a second stale RLDP in this repo. Deferred until a real multi-store catalog exists here; `covers` was taken now so the schema is ready.
- **`[graph-edge]` / `[graph-cascade]` triage categories, Structured Payload Coherence, Dependency Graph Mapping.** Software dependency graphs. No domain in this edition's target hubs has one.
- **`tests/golden-routing.test.sh` and its `demo-domain` fixtures.** They exercise RLDP, not linking, and `plugins/apiary` already carries an equivalent harness.
- **People Index / profile-promotion convention** (`assets/hub-template.md` in the work edition). Introduces a new `People/` folder convention; Obsidian backlinks cover the same need once links land.
- **`.codex-plugin/plugin.json`.** A second manifest to bump every release, for an audience not yet established here.
- **Install-pointer regressions, government vocabulary, and work-context examples carrying real names** — never copied.

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
