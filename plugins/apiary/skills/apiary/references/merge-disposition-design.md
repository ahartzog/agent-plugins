# Configurable Deliberation-MERGE Disposition — Design

A proposal, not yet implemented protocol. Companion to `protocol/custodian-workflow.md` §4.3 (the
canonical MERGE disposition rule) and `protocol/triage-policy.md`. Resolves the question left open
when 2.20.0 unified the disposition: the four disagreeing surfaces existed because the protocol
genuinely wanted **both** behaviors at different trust levels, and 2.20.0 picked one (auto-merge)
as a tiebreak rather than a conviction.

---

## The problem

A clean Chancellor MERGE — deliberation-path, no high-confidence critic objections, Loop D quiet —
currently joins the auto-merge batch PR. The human gate is post-hoc: a Signal post and a one-revert
rollback. That is the right default for a mature Hive whose codeowners trust Parliament, and the
wrong first posture for a brand-new CUI Hive — which is why the trial-period pattern (codeowner
review on *every* PR for the first month) already exists as folklore. Folklore is not
configuration: today the only lever is `parliament_push_mode: pr`, which gates **all** Parliament
output including the fast path — far coarser than the actual question, "does a human look at
deliberation merges before they land?"

## Proposal

One optional `hive.yml` field:

```yaml
triage:
  deliberation_merge: auto   # auto (default) | review
```

- **`auto`** — today's behavior, unchanged. Clean MERGE → auto-merge batch PR.
- **`review`** — clean MERGEs route to the **needs-review PR** alongside MERGE-with-objection and
  Loop D escalations. Fast path (`[link]`/`[person]`/`[tracker]`) is untouched — this knob is
  about *deliberated* content only, so capture ergonomics and the flywheel are unaffected.

Absent field = `auto` = current behavior; no migration (matches the absent-block-means-default
precedent set by `classification:` and `federation:`).

**Direction constraint: the knob only tightens.** `review` adds a human gate; nothing a Hive can
set weakens the upstream default or any other control. Same additive-only philosophy as gate
extensions — a Hive can only raise its own bar.

## Why this is the missing half of Loop C

Loop C tunes triage on approval ratios of *flagged* items. Under permanent `auto`, clean MERGEs
generate no approval signal at all — the loop can only ever observe the contested minority. Under
`review`, every deliberation merge produces a human verdict, which is exactly the evidence needed
to justify graduating:

- **Graduation:** a Hive starts at `review`; when Loop C's counters show ≥90% approval over the
  30-day window (`protocol/learning-loops.md` Loop C), the Brief/audit `[meta]` stub proposes
  flipping to `auto` — a CODEOWNERS PR against `hive.yml`, decided on measured evidence instead of
  vibes.
- **Demotion:** the post-merge false-positive counter (auto-merged facts attracting `[correction]`
  or `[contradiction]` within N days — the two-way-calibration extension to Loop C) proposes the
  reverse flip when `auto` proves premature. New `auto` Hives get a probation window during which
  the FP counter is checked every Parliament run.

The knob turns "trust Parliament" from a belief into a measured graduation with a return path.

## Interaction with existing controls

| Control | Relationship |
|---|---|
| `parliament_push_mode: pr` | Orthogonal and coarser: gates *all* Parliament output behind one PR. `deliberation_merge` selects *which PR* a clean MERGE joins. A Hive may set both; `review` is meaningful even under `push_mode: direct` (the needs-review PR is a PR regardless). |
| §4.3 canonical rule | Amended, stays canonical: "Clean MERGE **and** `deliberation_merge: auto` (default) **and** §4.1.05 did not fire → auto-merge batch." All deferring surfaces (triage diagram, §5, PR-type table, operational-model) already point here — one edit site. |
| Audit Step 4b (push-mode health) | Gains one line: report the resolved disposition, and when `review` has been held >60 days with a crossed Loop C threshold, surface the graduation offer (mirror of 4b's per-flow-override offer, same do-not-nag rule). |
| Profiles (future) | When a `profile:` governance axis ships, `regulated` implies `review` and `team` implies `auto`; this field remains the explicit override. Shipping the field first is deliberate — it is the bridge that works today and the profile later compiles down to it. |

## Schema and versioning

`hive.schema.json` gains an optional `triage` object with `deliberation_merge` (enum, default
`auto`). Optional field ⇒ **minor** version bump (new capability, no migration). Create mode Q5.5
area gains one interview question for CUI Hives only ("start in review posture? — recommended"),
defaulting to `review` for `max_level: CUI` and `auto` otherwise; greenfield UNCLASSIFIED Hives
are not asked.

## Open questions

1. Should `review` also gate fast-path *router* rows (the reference-library entries Parliament
   appends on `[link]` promotion)? They are the highest-frequency read surface (poisoning target),
   but gating them taxes the flywheel where it is cheapest. Leaning no for v1; the fast-path
   hardening item (router-text scan) addresses the same risk without a human in the loop.
2. Per-category granularity (`deliberation_merge` as a map keyed by tag)? Deferred — Loop C
   already reasons per-category, and a scalar knob plus Loop C's category-level proposals may be
   enough. Watch for a Hive that genuinely needs `[status]: auto` + `[architecture]: review`.
3. Does the trial-period pattern deserve first-class support (`review_until: <date>`)? Probably
   not — Loop C's evidence-based graduation is strictly better than a calendar.
