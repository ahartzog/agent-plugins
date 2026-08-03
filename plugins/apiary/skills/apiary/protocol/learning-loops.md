---
layer: PROTOCOL
type: learning-loops
description: "Four learning loops — Correction (A), Discovery (B), Calibration (C), Escalation (D) — that drive Hive Mind self-improvement; operational rules for session agents"
last_updated: 2026-07-30
codeowners: (read from hive.yml)
---

# Learning Loops

<CRITICAL>
Evaluate these loops on EVERY workflow execution. Before completing any workflow, check: did this session produce corrections, discoveries, quality signals, or contradictions — or fail to find something that should have been findable? If yes, the corresponding loop MUST fire before the session ends. Skipping loop evaluation is a protocol violation. Do NOT ask the user for permission — write to the inbox and push. The inbox is append-only and Parliament reviews everything; the cost of a bad contribution is near-zero, the cost of a lost discovery is permanent.
</CRITICAL>

Four feedback circuits that compound the Hive's knowledge over time. Design rationale: `references/learning-loops-design.md`.

Each loop has a **name** (what it does) and a **letter** (its stable identifier). Prefer the name in
prose; the letters remain valid and are retained because PR history, review comments, and telemetry
filenames reference them.

| Letter | Name | Trigger → effect | Fires in |
|---|---|---|---|
| A | **Correction** | a fact is wrong → the fact is fixed | session |
| B | **Discovery** | a fact is new → the fact is captured *and findable* | session |
| C | **Calibration** | flagging pattern → the triage gate is retuned | Parliament |
| D | **Escalation** | a fact keeps being challenged → the fact is disputed | Parliament |

A and B act on **facts**; C acts on **the policy that governs facts**; D acts on **confidence in a
fact**.

---

## Loop A (Correction): Corrections → Knowledge

User corrects a fact → `[correction]` inbox contribution with source → Parliament Skeptic verifies → Chancellor verdict → PR into `knowledge/`. Auto-merge if additive; human review if it contradicts existing fact.

---

## Loop B (Discovery): Discoveries → Knowledge

Session discovers new fact → progressive inbox write with `[tag]` → Parliament routes via `PROTOCOL/triage-policy.md`. Fast-path tags (`[link]`, `[person]`, `[tracker]`) auto-merge. Deliberation tags require tribunal.

### Loop B (Discovery) is not complete until the content is *findable*

A discovery that is never indexed is a lost discovery. Capture and findability are one obligation, not two. A knowledge file with no reference-library entry pointing at it is invisible to Ask — the next session asks the same question and gets "no information," which is worse than silence because the reader concludes the Hive has nothing to say.

**Every write into the corpus therefore carries an indexing obligation:**

| What was added | Index that must gain an entry | Who owes it |
|---|---|---|
| New `knowledge/**` file | the nearest `reference-library.md` | Parliament (Cartographer §4.1 / fast-path §3) |
| New external reference (URL, Confluence page, Jira board, document) | the nearest `reference-library.md`, or the `type: index` catalog covering that store | Parliament (§3 step 4, §4.1) |
| A document found via live search **and opened** | a `[link]` inbox contribution carrying the catalog row; Parliament appends it to the `type: index` catalog covering that store | the session writes the contribution (`routing-protocol.md` §Search / §Extract); Parliament writes the row (fast path §3 step 4) |
| Native source deposit into `sources/` | `sources/index.md` | Deposit workflow — a hard completion gate (`sources-policy.md` §Deposit step 5) |
| A question the reference-library could not route, **or a locator that would not resolve** | an inbox entry naming the gap | the session, at Ask time (`routing-protocol.md` §On no match) |

An index entry discharges this obligation only if it is **resolvable**. A pointer that names a document but cannot be turned into a fetch — no store root declared, no tool for the store — leaves the material as unreachable as if it were never indexed (`design-goals.md` §1, § The obligation this creates).

**Promoting a search-discovered document.** A document surfaced by §Search and opened is promoted by writing a `[link]` inbox contribution that carries the finished catalog row. This is a **hard completion gate** on the session: the opened document is not done until the contribution is written and pushed. Parliament appends the row to the `type: index` catalog covering the store on its fast path (`protocol/custodian-workflow.md` § Fast Path Processing, step 4, which already routes a named document in a catalogued store to that catalog rather than to a router URL). `[link]` is a fast-path tag, so the row auto-merges after CI — the gate costs the session one inbox write, not a review cycle.

**The session never writes `knowledge/`.** The catalog is a knowledge file, and `knowledge/**` is closed to agents (`protocol/security-policy.md` § Repository Protection Model; `design-goals.md` §4). Deposit's `sources/index.md` gate is not a precedent for writing here — `sources/` is a separate surface, deliberately outside `knowledge/`. What the session owns is the *contribution*; what Parliament owns is the *merge*.

- **Promotion requires a read, and covers every opened document.** A row earns its place only when its `covers` is content-derived. `covers` inferred from a filename is the thin-entry failure Goal 2 describes and must not enter the corpus. Every document the search opened is promoted, not only the one that answered — one contribution may carry several rows. Unopened candidates are **not** promoted; report them to the user as candidates worth a look and, if they suggest a coverage gap, record per §On no match.
- **A disproving read still promotes.** If the read shows the document is off-topic for the question, write the contribution anyway with corrected `covers` describing what it actually contains. The document exists and was genuinely absent from the catalog; the gap §Search found was real regardless of this question, and a correct row stops the next session re-discovering it. Apply the Skip criteria in `protocol/document-quality.md` § Trawling Heuristics first: a document that a trawl would decline to catalog is not promoted by a search either.
- **A newer revision of a catalogued document is a discovery, not a duplicate.** Promote it carrying `supersedes` (`protocol/document-quality.md` § supersedes, which also governs how the older row is re-marked). A catalog goes stale by revision more often than by omission, so dropping these as duplicates would leave the corpus pointing at a superseded document.
- **Mark provenance `discovered_via: search`.** This records that no human has reviewed the document's placement in the corpus. The `covers` text is content-derived either way; the marker is about placement review, not `covers` quality.

Rationale: `references/external-retrieval-search-design.md` § Why promotion requires a read, § Why the output shape is a catalog row.

**The session's share.** A session does not write `knowledge/` at all — not facts, not locators. What it *can* and MUST do without waiting for Parliament is write inbox contributions, and it owes two of them. First, record a routing gap the moment it observes one: a question the reference-library failed to route, or a knowledge file it only found by other means — a `[link]` or `[process]` contribution, written autonomously under the same discipline as any other Loop B write. Do not defer it on the assumption Parliament will notice; Parliament sees contributions, not the questions that failed. Second, discharge the promotion gate above: a `[link]` contribution carrying the catalog row for every search-discovered document it opened. Both are session-owned completion gates; neither is a `knowledge/` write.

**Telemetry:** `_custodian/reports/loop-b-gaps.json` — schema in
`references/learning-loops-design.md`; written by Parliament §6.2 as an idempotent rebuild from
gap-prefixed contributions (`coverage-gap:` / `routing-gap:` / `unreachable:`, per
`routing-protocol.md` §On no match) in `_inbox/` and `_inbox/_completed/`. Audit Step 3 and Brief
read it — the ranked gap backlog is the leading indicator of routing decay, and DESIGN-GOALS'
"fix the instrument before the thing it measures" makes this file the prerequisite for any further
RLDP tuning.

**Discoverability is Design Goal 9.** An artifact is not "contributed" until it is reachable — see `design-goals.md` §9, which requires every content surface to name its index, its write path, and its audit check. Audit enforces the read side (`mode-audit.md` Step 1b coverage check, § Source Index Integrity); this loop is the write side.

---

## Loop C (Calibration): Quality → Parliament Self-Improvement

**Mechanism:** approval-ratio feedback on triage routing. Human overrides a Parliament flag (approves what Parliament flagged) → rejection-override counter increments → if ≥90% approval in a category over rolling 30-day window → `[meta]` stub proposes moving that category to fast path → CODEOWNERS PR updates `PROTOCOL/triage-policy.md`.

**In one line, for restatement elsewhere:** *approval ratios tune the triage policy.* Any surface that restates Loop C (Calibration) must use the approval-ratio framing.

**Telemetry:** `_custodian/reports/loop-c-counters.json` — schema in `references/learning-loops-design.md`; written by Parliament §6.2 (which defines the observable signal: merge-state diff of previously-flagged PRs). Brief reads it to detect threshold crossings.

---

## Loop D (Escalation): Contradiction Velocity → Auto-Flag

When Parliament processes a `[contradiction]` for a fact that already has ≥1 prior `[contradiction]` in the rolling 30-day window → auto-tag fact as `[disputed]` → open `needs-review` PR with all contradiction sources linked → notify CODEOWNERS. Runbook step: `custodian-workflow.md` §4.1.05.

**Telemetry:** `_custodian/reports/loop-d-disputes.json` — schema in `references/learning-loops-design.md`; written by Parliament §6.2.

---

## Infrastructure

| Component | Purpose |
|---|---|
| `_inbox/` session files | Staging area — attributed, timestamped, one per session |
| `_inbox/_completed/` | Audit trail with reconciliation notes |
| `PROTOCOL/triage-policy.md` | Auto-merge vs flag rules (evolves via Loop C — Calibration) |
| `knowledge/**/reference-library.md` | Routing index — Loop B's (Discovery) discoverability gate (`mode-audit.md` Step 1b) |
| `sources/index.md` | Source manifest — Deposit's completion gate (`sources-policy.md`) |
| `_custodian/reports/` | Parliament run reports |
| `_custodian/reports/loop-c-counters.json` | Loop C (Calibration) telemetry |
| `_custodian/reports/loop-d-disputes.json` | Loop D (Escalation) telemetry |
| PR history on `knowledge/` | Decision accountability |
