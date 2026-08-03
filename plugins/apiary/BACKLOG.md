# Apiary Backlog

Open work, tracked so it doesn't get lost. Grouped by theme; ordered within groups by value.

Most items carry provenance and a confidence tag:
- **(audit 2026-08)** — from the multi-agent audit of this plugin (5 analysis lenses + 4 market
  researchers, every finding adversarially verified against the files). Its implemented output
  landed as 2.20.0–2.22.0; these are the survivors.
- **[confidence: high]** — verified defect/gap, or an externally *proven* pattern with a clear
  integration point. **[medium]** — promising, worth a design pass first. **[speculative]** — watch.

---

## Held — awaiting a human decision (do not start without it)

- [ ] **Inbox transport redesign (queue branch). ✅ APPROVED 2026-08-03** — Alek's team said yes
  to the queue-branch direction; Issues-as-second-transport remains optional follow-on. Next step
  is a design doc (`references/inbox-transport-design.md`) then implementation: long-lived
  unprotected `inbox` branch (master fully protected — required PRs + codeowners, no policy-bot,
  no CODEOWNERS narrowing), Parliament as the only bridge, `hive.yml.inbox_transport:
  default-branch (default) | branch` with upgrade-mode migration, Step 0 dual-ref fetch, Status
  reads pending entries from the queue ref, attribution captured in reconciliation notes before
  queue truncation, pathspec-limited + force-with-lease queue maintenance. Security bonus that
  motivated approval: a Sentinel-missed secret never enters master history, and queue history is
  cheaply rewritable for incident response. Full analysis: audit directives doc § I1. (audit
  2026-08) [confidence: high; MAJOR version — transport is a schema+behavior change]
- [ ] **Goal-4 carve-out for `audit --fix`.** `design-goals.md` §4 forbids agents opening
  `knowledge/` PRs; the remediation pass needs a narrow, named exception (human-invoked,
  findings-justified, codeowner-gated, never auto-merge). Decision + amendment must land with the
  implementation. See `references/audit-fix-design.md` § The Goal 4 question. (audit 2026-08)

## Designed — ready to implement (design docs exist)

- [ ] **Configurable deliberation-MERGE disposition** (`triage.deliberation_merge: auto | review`).
  Design: `references/merge-disposition-design.md`. Tighten-only knob; `review` feeds Loop C the
  approval evidence for graduation; demotion via the post-merge FP counter (see Two-way
  calibration below — the two ship best together). Optional field ⇒ minor bump. (audit 2026-08)
  [confidence: high]
- [ ] **Audit remediation pass — `/apiary audit --fix`.** Design: `references/audit-fix-design.md`.
  Audit's findings become the work queue; PR-only, delta-edits-only, coverage-check completion
  gate, ≤5 files/run. Blocked on the Goal-4 decision above. v1 scope: router compaction,
  `[superseded:]` retirement to an appendix, within-file dedup, `## Scope` refresh, trigger
  additions from `loop-b-gaps.json`. (audit 2026-08; external analogue: consolidation stage in
  every serious 2026 memory system) [confidence: high]

## Deterministic Enforcement (pair prose guidance with scripts)

The design principle: every "the AI should check for X" should be paired with "the system also
enforces X." Prose alone is not enough.

- [x] **Sentinel as an actual scanner — delivered (2.20.0).** 18 patterns compile into the pre-push
  hook; `scan`/`scan-dir` invoked by Parliament §0; classification banners baked from the ceiling;
  frontmatter + `sources/**.txt` scanned; excerpt-bound overrides. Remaining judgment-only:
  prompt-injection review and frontmatter/banner mismatch (Layer 3).
- [x] **Wire the seven `.test.sh` suites into CI — delivered (2.22.0).** Tier 1
  (`.github/workflows/apiary-tests.yml`): all seven suites on every `plugins/apiary/**` PR. Tier 2
  (`apiary-golden-behavioral.yml`): golden Part B via headless `claude -p` — weekly cron +
  `workflow_dispatch` + maintainer-applied `golden-behavioral` label on same-repo PRs only (secret
  boundary), transcripts uploaded as artifacts, model pinned via `APIARY_GOLDEN_CLAUDE_ARGS`.
  **Two repo-settings steps remain (Alek):** add the `ANTHROPIC_API_KEY` secret; mark
  `apiary-tests / suites` as a required check. Remaining nice-to-have: `claude plugin validate`
  in Tier 1 once the CLI is cheap to install there.
- [ ] **Deterministic prompt-injection pre-filter.** Three protocol files promise injection
  scanning at intake; there is no pattern list, no hook coverage, no test — and the check runs
  inside the very agent an injection targets. Add a small `injection` category to
  `sentinel-patterns.json` ("ignore previous instructions", role-override phrasings,
  system-prompt markers) that quarantines-for-review; LLM judgment stays as the second opinion.
  (audit 2026-08, verified) [confidence: high]
- [ ] **Optional gitleaks shell-out in the generated hook.** Keep the bundled patterns as the
  zero-dependency floor; when `gitleaks` is on PATH, also run `gitleaks protect --staged` for
  long-tail credential recall (700+ detectors vs our 16). Silent fallback when absent. Keep
  PII/classification in-house — no off-the-shelf scanner covers banner discipline. (market
  research: gitleaks/TruffleHog standard stack) [confidence: medium]
- [ ] **Pre-commit hook for size budgets.** Reject commits where a knowledge file exceeds 200
  lines or `agent-definition.md` exceeds 300 (design-goals § Size Budgets), shipped by Create mode.
- [ ] **Schema validation in CI.** `yq | ajv validate` against the four JSON schemas on every PR;
  today Create mode runs it once at scaffold time.
- [ ] **GHE pre-receive hook for CUI markers (server-side Layer 2).** The server-side backstop for
  `--no-verify` pushes; ship both variants from Create mode. The client-side Layer 0 banner scan
  is delivered.
- [ ] **Marking-required pre-receive hook for classified Hives.** Upgrade the advisory Layer 2
  variant to enforce frontmatter+banner discipline server-side; pair with CI so branches don't sit
  unchecked between pushes and Parliament runs.
- [ ] **Golden Part B grader: execution/grading split.** Keyword heuristics → separate grader
  subagent seeing only the case's Pass/Fail criteria + transcript (never the protocol files), n≥3,
  first-attempt gating. ~50-line change; stays opt-in. (audit 2026-08; AEVAL result: single-run
  same-agent grading of prose skills ≈ noise) [confidence: high]

## Runtime Performance

Delivered from this theme: compact RLDP rendering (2.21.0, −31% per Ask), restatement dedup
(2.22.0, ~−500/Ask, ~−1k/Parliament), one-call Step 0 (pre-existing).

- [ ] **Per-agent Parliament dispatch briefs.** Only the Apiculturist runs as a subagent today;
  Skeptic/Archivist/Cartographer/Reviser/Chancellor execute from the ~470-line runbook in main
  context (~25k tokens/run). Run each as a subagent receiving only its own §4.x brief + the
  contribution + grep context; main context keeps a ~150-line orchestration checklist. Also the
  judge-hygiene fixes: pin verdict temperature; blind the Chancellor to whether prose is
  contributor-original or Reviser-rewritten (self-enhancement bias). Est. 4–5k main-context
  tokens/run + less instruction slippage. (audit 2026-08) [confidence: high]
- [ ] **Step 0 self-resolving `{DEFAULT_BRANCH}`.** The branch-normalize check needs the value
  before the script cats `hive.yml`; a returning session on a `main`-defaulted Hive false-HALTs.
  Derive inside bash (grep hive.yml, fallback `git symbolic-ref refs/remotes/origin/HEAD`) like
  PERSONA_PATH already does; add the missing sparse-checkout paths (`/CLAUDE.md /README.md
  _metrics/ .signal/` — audit requires CLAUDE.md and sessions write `_metrics/`, both outside the
  sparse set today) and the missing Identity parse-list fields (push modes, classification,
  federation). (audit 2026-08, verified) [confidence: high]
- [ ] ~~Consolidated runtime protocol file~~ **Dropped.** Would create a third restatement surface
  of exactly the kind DESIGN-GOALS' lessons predict will drift; the compact-rendering +
  dedup approach (delivered) achieves the goal without a new surface.

## RLDP / Retrieval Quality

- [ ] **Routing trace + mechanical citation check.** End each Ask with a compact trace (libraries
  filtered → entries matched → sufficiency verdict → ranked candidates → locators resolved →
  documents opened), and require every §Answer citation to name a locator in the opened list.
  Cheapest version of a citation-verifier pass; makes golden cases assertable on structure; feeds
  Loop B telemetry the answered-from-opened ratio. (audit 2026-08; Azure agentic-retrieval
  activity/references pattern) [confidence: high]
- [ ] **Query restatement before §Match + optional `covers` column on router rows.** §Match is raw
  keyword collision between the asker's phrasing and the author's triggers — the weakest step, run
  on every Ask. Insert a 2–4-phrase restatement step (synonyms, document-vocabulary form, entity
  names); add an optional fourth `covers` column to reference-library tables (same semantics as
  catalogs, half-line budget). Explicitly NOT full decomposition/HyDE (ablations show unreliable
  payoff against the fetch economy). (market research: Anthropic contextual retrieval, −35–67%
  retrieval failure at index granularity) [confidence: high for restatement; medium for the column]
- [ ] **`sources/` read path in the RLDP.** The Hive's highest-fidelity representation is
  unreachable from a question: §Resolve has no `sources/` row and §Extract never falls through to
  the verbatim original when exact wording matters. Add `sources/index.md` to §Discover or a
  locator-kind row, plus an §Extract clause for exact-wording/value/requirement-text questions.
  (audit 2026-08; "verbatim beats extracted" ablation) [confidence: high]
- [ ] **Bi-temporal validity: `[effective: YYYY-MM-DD]` inline annotation.** `[learned:]` conflates
  ingestion time with world-validity; audit staleness runs off file-write dates; §Prefer's status
  rule ranks on the wrong clock. One optional annotation ("true in the world since"), one clause
  in §Prefer, audit Step 2 decays from it when present. Do NOT adopt a graph substrate — the
  annotation carries the value. Mirror to second-brain per the shared-taxonomy contract. (market
  research: Graphiti bi-temporal, the measured source of its temporal-reasoning lead) [confidence:
  high]
- [ ] **Freshness-aware §Prefer tiebreak.** When candidates are otherwise comparable, prefer the
  one whose `decay`/`last_updated` posture is healthier, and caveat a stale winner. One bullet;
  reuses knowledge-schema's decay thresholds. (audit 2026-08) [confidence: medium]
- [ ] **Standing contradiction sweep (audit Step 2c).** Contradictions are detected only at write
  time; two facts contributed months apart coexist forever — the failure a multi-human Hive is
  most exposed to. Sample `register`/`status` files sharing a `domain`, run an LLM contradiction
  pass, emit `[contradiction]` inbox contributions (never edits). Feeds Loop D its latent cases;
  bound cost by domain-scoped sampling. (audit 2026-08; MemClaw "contradiction persistence"
  failure mode) [confidence: medium]
- [ ] **Write-side novelty gate ("re-tag, don't skip").** Every re-observation of a known fact
  costs a full tribunal pass. ~5 lines in workflows § Cross-Cutting Discipline: before writing,
  grep the routed target file (already in context from Ask) for the claim's key entity; on a
  match, write `[correction]`/`[contradiction]` instead of a bare discovery; skip only exact
  restatements. The lost-discovery asymmetry stays the tiebreaker. (market research: Mem0/SAGE
  ADD/NOOP routing, adapted infra-free) [confidence: medium]
- [ ] **Record the vectorless-retrieval evidence in `external-retrieval-design.md`.** The
  no-embeddings choice is now the research-validated *better* architecture at Hive scale
  (Anthropic removed vector search from Claude Code for grep; "Is Grep All You Need?"; 94.5%-of-RAG
  at zero infra), not merely the zero-dependency concession — write the citations down so the
  first "let's add a vector DB" proposal meets them, and name the revisit trigger: a Hive passing
  ~1–2k indexed documents with `loop-b-gaps.json` showing misses dominated by paraphrase failures
  rather than coverage gaps. [confidence: high — one paragraph]
- [ ] **Local cache for fetched external documents.** §Resolve re-fetches every Ask; §Search's
  verification read fetches a winner twice. Design sketch exists
  (`references/external-retrieval-caching-design.md`): per-user gitignored cache keyed by
  canonical URL, TTL for hygiene + store validators for correctness, classification-gated default.
  [confidence: high on design; execution reliability is its own open question §1]
- [ ] **Migrate store-relative catalog rows to absolute URLs.** One-time pass per Hive; folder-level
  rows need a decision. Cleanup, not a blocker.
- [ ] **Fetch-disposition on the entry** (`load` | `cite-only` | `query-live`). The
  classification-exposure driver is live: §Search's augment path assumes rows are a cache to
  revalidate globally; a per-entry disposition states it locally.
- [ ] **Corpus-wide re-trawl automation.** §Search repairs one asked question at a time; audit
  Step 2b detects staleness but only recommends. Explicitly OUT of `audit --fix` v1 scope — needs
  its own owner (Parliament vs scheduled job) and dedup story.
- [ ] **Re-home `tool-tiers.md` as a resolver registry.** Org-wide reference data masquerading as
  protocol; the hand-edit-a-copy extension mechanism is the drift pattern 2.12.0 fixed for
  routing. Split standard resolvers (upstream) from Hive-registered ones (additive).

## Learning Loops & Calibration

Delivered: Loops C/D runbook wiring + telemetry (2.20.0); Loop B telemetry + gap-mining prefixes
(2.22.0); Write Operations taxonomy (2.20.0).

- [ ] **Two-way calibration: post-merge FP counter + demotion rule + probation.** Loop C is a
  one-way ratchet — its only learned behavior is to review *less*. Count auto-merged facts that
  attract `[correction]`/`[contradiction]` within N days; a fast-path category (or an `auto`
  disposition) exceeding the threshold demotes back via the same CODEOWNERS-PR mechanism; newly
  promoted categories get a probation window. Ships best WITH the merge-disposition knob. (audit
  2026-08; ClueBot target-FP-rate + Wikipedia trial-regime patterns) [confidence: high — the
  clearest structural defect the audit found]
- [x] **Loop C observability — delivered (2.20.0).** `_custodian/reports/loop-c-counters.json`,
  written by Parliament §6.2 as an idempotent 30-day window rebuild; audit Step 3 reads it.
- [ ] **Brief mode runbook (`references/mode-brief.md`).** Still unspecced; now has real inputs
  (loop-b-gaps.json for the gap ranking, loop-c threshold crossings to convert into `[meta]`
  stubs). Highest-leverage artifact for stakeholder buy-in per unit engineering — it is what
  non-contributors see. (audit 2026-08) [confidence: high]

## Multi-Consumer Guardrails

- [ ] **Domain-neutral `authority` definitions + upstream taxonomy packs.** The enum stays closed
  (rankability needs a total order) but its middle tiers are program-worded ("Milestone-frozen
  (CDR/PDR submitted)") — product/ops Hives flatten to a two-point trust scale, corrupting
  §Prefer's mechanical ranking. Reword the four values as trust levels with per-profile example
  mappings; ship `assets/taxonomy/{program,product,ops,personal}.yml` packs referenced by name so
  every product Hive stops convergently reinventing {runbook, design-doc, postmortem} in
  per-catalog `doc_type_extensions`. Mirror to second-brain (shared-taxonomy contract). (audit
  2026-08, verified) [confidence: high]
- [ ] **Codeowner attention budget.** The human bottleneck has no budget: `[meta]` always
  escalates, quarantine always notifies, no SLA, no aggregation for deliberation outcomes, no
  expiry, repo-scoped routing. Batch deliberation-outcome notifications per run; make queue
  depth/age a first-class audit metric; auto-disposition untouched escalations after N days
  (`confidence: low` + `[disputed:]`, never silent rot); support per-directory codeowner routing;
  state the expected cadence in the child README so the role is a commitment, not an ambush.
  (audit 2026-08; Wikipedia's reviewer-load lesson) [confidence: high]
- [ ] **Named verifier + reader-facing staleness.** `decay`/`review_by` exist but nobody *owes*
  re-verification and a reader citing a stale file sees no warning (Goal 1's own argument: a stale
  copy actively misleads). Optional `verifier:` frontmatter; audit opens one assignment PR per
  verifier instead of a flat report; Ask renders "unverified since X" when citing past-review
  files. (market research: Guru's SME-verification model — the KM category's best mechanism)
  [confidence: high]
- [ ] **Event-driven catalog staleness.** Store `source_modified` per row at trawl/promotion time;
  a custodian job compares live store mtimes and emits `[correction]` contributions on drift —
  converts the weakest staleness surface (Step 2b admits calendar checks can't cover it) into the
  strongest, reusing store roots + tool-tiers + supersedes. (market research: Swimm's
  watermark-the-source insight) [confidence: medium]
- [ ] **Aggregate usage counters.** knowledge-schema already sanctions the tier ("read-time usage
  telemetry belongs in a disposable retrieval cache") — nothing was built. Counters under
  `_custodian/reports/` rank the stale-file backlog, gate auto-archive proposals, and prioritize
  gap-filling. Without them audit emits an unprioritized report at 30-instance scale. [confidence:
  medium]
- [ ] **Contribution volume/quality guards (the AI-slop defense).** Keep autonomous capture (it IS
  the flywheel) but stop asserting its cost is near-zero — the cost lands on deliberation and
  codeowners. Cost-per-contribution counter in the run report; advisory (non-blocking) pre-push
  quality checks predicting known rejection reasons (`[status]`/`[correction]` without source,
  missing `[learned:]`, no resolvable target, near-duplicate); per-session budget with
  summarize-and-batch fallback. (audit 2026-08; the curl/HackerOne 2025-26 episode is the
  cautionary case) [confidence: high]
- [ ] **Fast-path poisoning hardening.** Router text is a low-privilege write into the
  highest-frequency read surface (every Ask loads it): run the Sentinel scanner over rendered
  router-row text, constrain `Triggers` to a keyword grammar, cap per-run fast-path router
  additions. Land BEFORE Loop C's promotion machinery gets exercised — Loop C actively pushes
  categories toward the fast path. (market research: OWASP ASI06 memory poisoning; detectors miss
  ~66%, so the control is structural, not a classifier) [confidence: high]
- [ ] **Expert routing as the §On no match fallback.** Before recording a gap, resolve the nearest
  topic owner (CODEOWNERS + people profiles + contribution history) and return them as the answer
  of last resort — converts a dead end into a probable future contribution. (market research:
  Glean expert detection / transactive-memory literature) [confidence: medium]
- [ ] **Contributor recognition digests.** Goal 5 names the flywheel as load-bearing; there is no
  recognition surface at all. Signal posts name contributors whose entries merged; periodic digest
  (merged-by-person, gaps still open, later "cited N times" once usage counters exist). Near-zero
  engineering — the posting path exists. [confidence: medium — pair with visible leadership use]
- [ ] **Fleet health scorecards via the registry.** The Apiculturist already reconciles every Hive
  against the central registry per run — the ideal carrier for a per-Hive health score (audit's
  structural/freshness/loop results) and the fleet view that answers "are the 30+ instances
  actually healthy?" (market research: Backstage Soundcheck) [confidence: medium]

## Profiles & Second-Brain Unification

Supersedes the old "hive.yml protocol toggles" sketch, which the audit found contradicts
design-goals §4 outright ("Sentinel is non-negotiable" vs "a local Hive would disable sentinel")
and would dangle cross-file dependencies (Loop B's promotion gate terminates in Parliament; every
triage tag's path is a Parliament path). The reframe: **three orthogonal axes over an invariant
core** — what a local Hive lacks is a push boundary and a second reviewer, not scanning.

- [ ] **`profile:` block in hive.yml** — `{governance: solo|team|regulated, backend:
  git-remote|git-local|dir, taxonomy: program|product|ops|personal|custom}`; absent block =
  `{team, git-remote, program}` = today. `solo` = user-is-Chancellor, in-place incorporation, no
  Signal; Sentinel's *patterns* stay universal, only the enforcement point moves. Protocol
  sections declare which tiers bind them; individual toggles survive only as a schema-validated
  expert escape hatch. Major version. Design doc first. (audit 2026-08) [confidence: high on the
  axes; the section-binding mechanism needs the design pass]
- [ ] **Storage backend abstraction** (`push`/`commit`/`inbox` as operations per backend) — axis 2
  of the above; BACKLOG's original framing stands.
- [ ] **Second-brain as the L1–L3 on-ramp; retroactive schema compatibility; protocol inheritance
  for local Hives** — original items stand, now routed through the profile model.

## Open-Sourcing / Public Repo

The repo is now public (agent-plugins, 2026-08-03). Ordered by launch impact:

- [ ] **CI as the credibility floor** — see Deterministic Enforcement above; precondition for
  promoting the repo, not hygiene.
- [ ] **Local mode as the launch feature.** `apiary create --local`: plain directory or plain
  GitHub repo; knowledge schema + RLDP + audit + loops; no Parliament/Signal/classification —
  federation and the tribunal become the graduation story, not the entry fee. The current
  six-step, org-coupled onboarding is a hard stop for anyone outside. Mechanism: the `profile:`
  work above. (audit 2026-08 ecosystem research) [confidence: high]
- [ ] **Naming + jargon budget.** "Hive Mind" collides with the ~31k-star swarm-orchestration
  referent (claude-flow) — readers will assume swarms and bounce. Keep **Apiary** and **Hive**,
  drop "Hive Mind"; ≤3 proprietary nouns above the fold (Apiary, Hive, Parliament); one-paragraph
  preempt: "Parliament is a review tribunal, not a build swarm." Spend SKILL.md's description
  budget on what a stranger would type. [confidence: high; naming is Alek's call]
- [ ] **Genericize the five structural couplings.** (1) classification → a pluggable sensitivity
  ladder (`levels: [public, internal, confidential]` + ordering) — the marking-discipline
  *mechanism* generalizes to PHI/PCI/trade-secret unchanged; (2) registry → URL or file path;
  (3) Signal → generic webhook with a Slack adapter; (4) CI templates → dir with a GitHub Actions
  variant; (5) tool-tiers → the resolver-registry split above. [confidence: high]
- [ ] **Native plugin dependencies + version-clock split.** Child plugin.json declares
  `{"name": "apiary", "version": "^2.0"}`; tag releases (`claude plugin tag --push`); Upgrade mode
  narrows to hive.yml *content* migration; `upstream_version` stays the data-schema clock,
  distinct from the plugin-version clock. Document the two working cross-marketplace topologies
  before an external adopter hits the `cross-marketplace` install error. (ecosystem research:
  first-party dependency support now exists and is better than the prose check) [confidence: high]
- [ ] **Extract the golden-cases pattern as a standalone generic artifact.** "Golden behavioral
  cases for prose protocols" (RIGHT/WRONG + governing-clause citation + anti-tamper notes) is the
  most publishable idea in the repo and costs nothing to genericize — fixtures are already
  synthetic. Likely out-stars the mothership and funnels back. [confidence: medium]

## Template Rendering

- [ ] **`scripts/render-templates.sh`** — render all templates from hive.yml in one pass; kills
  the `CODEOWNERS_CSV`-drift class. Create mode Step 2 invokes it.
- [ ] **Placeholder drift check** — compare `hive.yml.codeowners` against the `.claude/settings.json`
  reviewer list in the Step 4 checks.

## Discoverability / Examples

- [ ] **`references/example-agent-definition.md`** and **`references/example-knowledge-file.md`** —
  worked examples beside the placeholder-heavy templates.
- [ ] **Known-good Hive registry** (`references/role-model-hives.md`) once patterns stabilize.

## Schema Completeness

- [ ] **`_custodian/config.yml` schema** — the fourth identity contract.
- [ ] **Signal config schema** — one field today; capture the shape before it grows.
