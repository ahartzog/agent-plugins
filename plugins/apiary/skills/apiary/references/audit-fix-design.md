# Audit Remediation Pass (`/apiary audit --fix`) — Design

A proposal, not yet implemented protocol. Companion to `references/mode-audit.md` (whose findings
become this pass's work queue) and `protocol/learning-loops.md`. The industry analogue is the
"consolidation" / sleep-time-compute stage every serious 2026 agent-memory system ships
(Anthropic's "dreaming", ACE's Curator, Letta's sleep-time agents); the Apiary shape is
deliberately humbler: **audit gains a write mode**, not a new mode.

---

## The problem

Nothing in the system ever edits the corpus *down*. Parliament admits new content one contribution
at a time and never revisits what it merged; audit detects — over-budget reference-libraries,
lines carrying `[superseded:]` forever, near-duplicate facts, stale `## Scope` headers, recorded
routing gaps nobody actions — and then stops, because its WARNs have no remediation procedure
attached. So `knowledge/` grows monotonically, the routers drift toward their size caps, and the
answer to "this file is over budget" is a report line nobody owns.

## Shape: a follow-on to audit, not a fifth mode

`/apiary audit --fix` runs the normal audit first, then a remediation pass **driven only by the
findings the audit just produced**. One flag, no new SKILL.md dispatch row, no new runbook surface
— the audit report *is* the work queue, which keeps detection and remediation from drifting apart
(a standalone consolidation mode would re-derive its own findings and eventually disagree with
audit about what needs fixing).

Read-only audit keeps its trust property: `/apiary audit` remains runnable by anyone with no write
auth and no lock. `--fix` additionally requires push access and takes the Parliament lock
(`custodian-workflow.md` §1.1) for its write phase, since it shares the fresh-clone machinery.

## What v1 fixes (and what it refuses)

| Audit finding | Remediation | Bound |
|---|---|---|
| Reference-library over 200 lines (Step 1b) | Convert block-form entries to table rows; merge rows sharing triggers per the aggregation rule | Never drops an entry; row count may only fall via merges that preserve every trigger term |
| Lines carrying `[superseded: …]` older than 90 days (Step 2 adjunct) | Move to a `## Superseded` appendix at file end (out of the hot read path) | Never deleted; `[disputed:]` lines never touched |
| Near-duplicate facts within one file | Merge into one line keeping the earliest `[learned:]` and all annotations | Within-file only; cross-file dedup is out of scope for v1 |
| Stale `## Scope` headers (library content drifted since authoring) | Regenerate the 2–4 line scope from the library's current entries | The single highest-leverage fix: §Filter reads Scope and nothing else, and today nothing ever updates it |
| Recorded routing gaps (`loop-b-gaps.json`, Loop B telemetry) | Draft trigger-keyword additions to the covering library's rows — ground truth about what askers actually said, vs the author's guesses | Additive rows/terms only |

**Refused, permanently or for v1:** deleting any content (supersede/appendix, never remove);
cross-file restructuring; catalog re-trawls (a different mechanism with a different owner —
BACKLOG § re-trawl automation); touching `_inbox/`, `sources/`, or `PROTOCOL/`; anything in a file
audit did not flag.

## Safety rails (each one load-bearing)

1. **PR-only, never auto-merge, never direct push.** Output is exactly one codeowner-reviewed PR
   per run, auto-merge *not* requested. This is the review posture Anthropic chose for dreaming's
   output, and it is what makes the pass safe to run on a schedule.
2. **Delta edits only — wholesale rewrites are forbidden.** The measured failure mode of "LLM,
   please compact this file" is silent detail loss ("context collapse", ACE): the model rewrites
   the document and specific routing coverage evaporates. Every change is a line-level edit
   (merge these two rows, move this line, rewrite this header) enumerated in the PR body against
   the audit finding it discharges.
3. **Coverage check as completion gate.** Audit Step 1b's coverage matcher runs before and after;
   any knowledge file reachable before must be reachable after, and any trigger term present
   before must survive (in the same or a merged row). A failed gate aborts the PR — the pass may
   not trade routing coverage for line count.
4. **Size-bounded runs.** At most N files touched per run (propose 5). A backlog burns down over
   several runs; a 40-file remediation PR is unreviewable, and unreviewable defeats rail 1.
5. **Attribution preserved.** Merged lines keep every `[learned:]`/`[decided:]` annotation;
   moved-to-appendix lines move verbatim.

## The Goal 4 question (must be settled before implementation)

`protocol/design-goals.md` §4 says agents use the inbox path only and "must not open PRs that
modify `knowledge/` directly." An unamended reading forbids this pass. The resolution this design
proposes: a **narrow, named carve-out** — the remediation pass may open a `knowledge/` PR when
(a) a human invoked `--fix` (the human is the actor-with-intent; the agent is the typist),
(b) the PR carries the audit findings as its justification, and (c) codeowner review is required
with auto-merge never requested. The gate is not removed, only relocated — the same sentence Goal
4 already uses to bless the human direct-PR path. Amending design-goals.md §4 is itself a
CODEOWNERS PR and should land *with* the implementation, not before or after.

The alternative — routing remediation through `_inbox/` contributions for Parliament to apply —
was considered and rejected: compaction edits are file-shaped, not line-item-shaped; fragmenting
"convert this library to table form" into inbox entries is the exact ceremony-not-safety failure
the Human Direct-PR Path rationale already names.

## Cadence and telemetry

On demand at first. Once boring: monthly, or triggered by audit's own signal (≥K over-budget
WARNs). Each run appends to the audit report: files touched, lines merged/moved, trigger terms
added from gap telemetry, coverage-gate result. If a run finds nothing to fix, it says so and
opens no PR.

## Open questions

1. Scope-header regeneration is the one fix that *replaces* prose rather than moving it — does it
   need its own sub-gate (old header quoted in the PR body for diff-eyeballing)? Probably yes and
   cheap.
2. Should trigger-addition drafting stay in `--fix` or move to Parliament's fast path once Loop B
   telemetry exists? Keeping it here means one review surface; moving it means faster landing.
   Start here, revisit when `loop-b-gaps.json` has real volume.
3. Does `--fix` ever run the behavioral golden suite as its own completion gate? Attractive but
   expensive; the coverage matcher (rail 3) is the deterministic proxy. Revisit if a remediation
   PR ever ships a routing regression the matcher missed.
