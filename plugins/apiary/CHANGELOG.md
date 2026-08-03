# Changelog

All notable changes to the **apiary** plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this plugin uses [Semantic Versioning](https://semver.org/). The version at the top of each release must match `.claude-plugin/plugin.json`. See the repo-level [CONTRIBUTING.md](../../CONTRIBUTING.md) for change and versioning discipline, and this plugin's [CONTRIBUTING.md](CONTRIBUTING.md) for the mandatory scenario verification.

## [2.21.0] — 2026-08-03

### Changed
- **Compact RLDP rendering** (`protocol/routing-protocol.md`): the canonical routing file drops from 277 lines (~4.8k tokens) to 189 (~3.3k) — a ~31% cut on the fixed cost of **every Ask** across every Hive — by demoting design rationale to the `references/*-design.md` files where principle 10 says it belongs. Zero normative change: every § step name, every rule, and every sentence the golden suite pins survives verbatim (verified by phrase-level check + full suite + behavioral Part B). New rationale sections in `external-retrieval-design.md`: "Why recency is resolved mechanically" (with the research citation, so the deterministic-sort rule can defend itself) and "Why the sufficiency test sits on the catalog-rows set".

## [2.20.1] — 2026-08-03

### Changed
- Marketplace renamed `ahartzog-skills` → `ahartzog`; install pointers emitted by this plugin updated accordingly (`references/mode-operate.md`, `assets/child-skill-template.md`, `README.md`). No behavior change.

## [2.20.0] — 2026-08-02

Protocol-consistency and deterministic-enforcement release, produced from a deep multi-agent audit (5 analysis lenses + 4 market researchers + adversarial verification) of the 2.19.0 export.

### Fixed
- **Canonical MERGE disposition rule** (custodian §4.3): four surfaces disagreed on whether a Chancellor-approved deliberation contribution auto-merges or waits for CODEOWNER review — the rule that decides whether human review happens. Now stated once (clean MERGE → auto-merge batch; MERGE-with-objection or Loop D fired → needs-review PR); triage-policy and operational-model defer to it.
- **RLDP loads on every Ask** (mode-operate Step 2 said "unless the routing table resolved the question", silently skipping §Search sufficiency and §On no match gap capture).
- Defense layers renumbered to one scheme file-wide (L0 pre-push hook / L1 session redaction / L2 GHE pre-receive [optional] / L3 Parliament Sentinel); FOUO removed as a selectable ceiling everywhere; dangling `docs/…design.md` spec pointers replaced with inline escalation-PR + reconciliation-note templates; step-renumbering drift fixed in 7 files; mode-audit's Loop A check rewritten in Apiary terms (was Second Brain vocabulary that vacuously passed).
- **Sentinel regex bugs:** `\s` inside POSIX bracket expressions (literal backslash — connection-string could never match a password containing "s") and token-literal's `[_\-.]` decreasing-range error, swallowed by stderr redirection, meaning the pattern never matched anything. All patterns rewritten to `[[:space:]]` classes.

### Added
- **Sentinel hardening:** frontmatter scanning (override block excluded); `sources/**.txt` coverage; classification-banner scan baked from `hive.yml.classification.max_level` (banner-shaped only; path references stay sanctioned; `classification.*` never overridable); excerpt-bound `sentinel_override.matches`; 6 new patterns (fine-grained/OAuth GitHub tokens, `xoxe-`, Azure AccountKey + SAS, JWT, Bearer header); quarantine now redacts and the report masks values; Credential Remediation Runbook (rotate first, then purge).
- **Parliament deterministic scan** (custodian §0): the generated hook's `scan-dir` is now a literal runbook command; scan-dir walks `sources/` too.
- **Loops C and D actually fire:** §4.1.05 prior-contradiction check (second challenge in 30 days → `[disputed:]` + needs-review PR); §6.2 writes both telemetry files via an idempotent 30-day-window rebuild; housekeeping stages `_custodian/reports/` + `_metrics/`.
- **Write Operations taxonomy** (triage-policy): tags imply ADD / SUPERSEDE (paired in-place edit) / ANNOTATE; deliberately no DELETE. Reviser emits the paired `[superseded:]` edit.
- **RLDP:** §Recurse boundary defined (first router→catalog hop is §Extract, not a traversal); sufficiency verdict stated in one auditable line; deterministic recency (extract dates, sort, then choose) and one-pass table ranking; §On no match carve-out for local reads and covers-answers; §Answer completion gates; concurrent two-store search dispatch; rarest-term-first catalog grep.
- **Golden suite:** Cases 13 (recency/sufficiency-verdict) and 14 (abstention + gap capture) with Part B judges; five Governing-line quote attributions corrected; Part B timeout portability (macOS). Sentinel suite 23 → 68 assertions incl. a positive test per pattern; sentinel-base 12 → 14 (sources/*.txt pre-push path).
- **README:** dual-audience rewrite — beginner explainer with mermaid architecture/loop/RLDP diagrams, a "Where decisions actually get made" authority ladder, and a dense Protocol Contract for LLMs.

### Verification
All seven suites green (clone-flow 8, apiculturist 29, normalizer, golden Part A 33, gate-extensions 36, sentinel-base 14, sentinel 68); golden Part B behavioral half 7/7 live-agent cases pass, including the new sufficiency-verdict and abstention cases. Changes adversarially reviewed by four independent agents; all confirmed findings fixed.

## [2.19.0] — 2026-08-02

Wholesale import of the current (sanitized) Hive Parent Protocol export, bringing this copy from the 2.4.0 snapshot to the 2.19.0 protocol lineage. Repo identity (plugin name `apiary`, MIT license, this changelog) preserved; all organization-specific references remain fictional placeholders. Highlights of the imported lineage (full detail: `skills/apiary/references/mode-upgrade.md` § Version Notes):

### Added
- **RLDP consolidation (2.12.0):** `protocol/routing-protocol.md` is the canonical, upstream-owned Reference Library Discovery Protocol; personas reference it instead of carrying frozen inline copies. §On no match gap-recording is mandatory.
- **Learning loops named + enforced (2.13.x):** Correction / Discovery / Calibration / Escalation; Loop B binds capture and findability as one obligation; directory pointers are canonical.
- **External retrieval as a first-class routing step (2.16.0):** `Load` split into §Resolve/§Extract; `covers` catalog field; store roots for `type: index` catalogs; Store Kind → Tool table.
- **Gate extensions (2.15.0):** Hive-specific pre-push hardening baked into the generated hook, structurally unable to suppress the Sentinel.
- **Merge-base fix for the pre-push hook (2.16.1)** plus `sentinel-base.test.sh` regression suite.
- **Live store search (2.19.0):** RLDP §Search — miss and augment paths, search subagent contract (`protocol/external-search-agent.md`), promotion-requires-a-read, catalog staleness audit check.
- **Apiculturist registry reconciliation (2.11.0)** and federation opt-outs; per-flow push modes (2.6.0); sources deposit path; golden routing/retrieval test suite (`tests/golden/`).

## [2.4.0] — 2026-06-10

The Hive Parent Protocol at **2.4.0**. Earlier version history predates this repo; tracking starts here.

### Added
- Hive Parent Protocol modes: create / operate / audit / upgrade.
- Parliament triage (inbox → curated knowledge), Sentinel scanning, and custodian health checks.
- Git-backed multi-contributor knowledge bases with a self-healing clone/sync flow (first install, remote-ahead pull, rogue-branch recovery).
