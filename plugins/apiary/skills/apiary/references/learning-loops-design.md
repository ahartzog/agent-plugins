# Learning Loops — Design Rationale

Design context and telemetry schemas for the four learning loops defined in `PROTOCOL/learning-loops.md`. This file is loaded on demand (Audit, or when someone asks "why do the loops work this way"), not on every session.

---

## The Compaction Problem (Why Loops Matter)

In single-user Claude Code, corrections go to memory files. Memory gets compacted. Nuanced corrections become one-line summaries. The correction evaporates. The same mistake recurs.

In the Hive Mind, this problem is **worse** — corrections come from multiple people across multiple sessions. If they only land in individual users' memory files, the shared persona never learns. The loops ensure corrections reach the shared knowledge base, not just individual memory. [learned: 2026-04-16]

**The principle:** Every correction must land where it will be loaded and enforced automatically in future sessions, by any user. Memory alone is not enough. The `knowledge/` layer is the enforcement point.

---

## Loop A (Correction): Why Parliament Instead of Direct Write

**Second Brain pattern:** User corrects agent → agent updates its own file directly.

**Hive Mind adaptation:** Corrections come from multiple sources with varying authority. The PR mechanism makes the correction decision visible, attributed, and auditable. A correction from someone with deep domain expertise carries different weight than one from a peripheral contributor — and that distinction must be visible, not hidden.

```
User notices wrong fact during session
  → contributes [correction] with source
    → Parliament Skeptic verifies source
      → Chancellor verdict
        → knowledge base updated (or escalated if source insufficient)
          → future sessions load the corrected fact
```

---

## Loop B (Discovery): Why Progressive Inbox Instead of Direct Write

**Second Brain pattern:** Session discovers fact → direct write to knowledge file.

**Hive Mind adaptation:** In multi-owner context, the triage policy prevents one session's misunderstanding from becoming shared "knowledge." The inbox provides a staging area where contributions are attributed, timestamped, and categorized before touching the shared base.

```
Session discovers new fact (link, person, status, architecture, etc.)
  → writes to session inbox file with [tag]
    → Parliament routes via triage policy
      → fast path: auto-merges in batch PR
      → deliberation: council evaluates, Chancellor decides
        → knowledge base grows
          → future sessions start from higher ground
```

---

## Loop B (Discovery): Why Findability Is Part of the Loop, Not a Separate Concern

Capture is not the whole job. A knowledge file that no reference-library entry points at is unreachable, and from the reader's side unreachable is indistinguishable from missing — worse, because "no information" reads as *the Hive has nothing on this* rather than *the Hive cannot find what it has*.

Indexing belongs inside the loop rather than tracked beside it because the two obligations share a trigger and a cost profile. The session that learns something is the session that knows which triggers would have found it. Deferring the index write loses that context, and nothing schedules a later pass. [learned: 2026-07-30]

Note the asymmetry in who owes what. Sessions cannot write `knowledge/`, so the index entry for a *new knowledge file* is necessarily Parliament's (Cartographer). But the **routing gap** — "I asked this and the library could not route it" — is only observable at Ask time and is therefore the session's obligation. Parliament sees contributions, never the questions that failed. That gap-recording duty is what `routing-protocol.md` §On no match exists to enforce.

---

## Loop C (Calibration): Why Approval Ratios Matter

**Second Brain pattern:** User catches issue custodian missed → update custodian checklist.

**Hive Mind adaptation:** The Hive has a feedback signal that single-owner systems don't: the ratio of flagged items that humans approve vs reject. A triage policy that's over-flagging items that humans consistently approve is miscalibrated. The loop tunes it.

```
Parliament flags a contribution for human review
  → human approves (it was fine)
    → rejection-override counter increments for that category
      → if threshold reached → proposal to relax triage policy
        → CODEOWNER PR updates triage-policy.md
          → future Parliament runs flag less aggressively in that category
```

**Calibration rule:** ≥90% approval in a category over rolling 30-day window → consider moving to fast path. Policy changes require CODEOWNERS PR against `PROTOCOL/triage-policy.md`. [learned: 2026-04-16]

### Loop C (Calibration) Telemetry Schema

Parliament writes to `_custodian/reports/loop-c-counters.json` after every run:

```json
{
  "counters": [
    {
      "category": "[correction]",
      "window_start": "2026-03-18",
      "window_end": "2026-04-17",
      "approvals": 42,
      "rejections": 3,
      "overrides": 1,
      "sample_size": 46,
      "approval_rate": 0.913,
      "threshold_met": true
    }
  ],
  "last_updated": "2026-04-17T14:30:00Z",
  "parliament_run_id": "parliament-2026-04-17-001"
}
```

When `threshold_met: true`, the Brief workflow generates a `[meta]` inbox stub proposing triage policy relaxation, linking to this counter file for evidence.

---

### Loop B (Discovery) Telemetry Schema

Parliament rebuilds `_custodian/reports/loop-b-gaps.json` on every run (idempotent — recomputed
from the rolling 90-day window of gap-prefixed contributions, never incremented). Dedup key: the
gap kind plus normalized description (lowercased, whitespace-collapsed, locator URLs canonicalized).

```json
{
  "window_start": "2026-05-05",
  "window_end": "2026-08-03",
  "gaps": [
    {
      "kind": "coverage-gap",
      "summary": "thermal vacuum test schedule",
      "count": 4,
      "first_seen": "2026-06-11",
      "last_seen": "2026-07-30",
      "sessions": ["2026-06-11-jdoe-...", "2026-07-30-asmith-..."]
    },
    {
      "kind": "unreachable",
      "summary": "ground-segment/broken-catalog.md row 'Legacy Command Format Register' — no store root",
      "count": 2,
      "first_seen": "2026-07-01",
      "last_seen": "2026-07-28",
      "sessions": ["..."]
    }
  ],
  "totals": { "coverage-gap": 6, "routing-gap": 3, "unreachable": 2 },
  "last_updated": "2026-08-03T14:30:00Z",
  "parliament_run_id": "parliament-2026-08-03-001"
}
```

`kind` ∈ {`coverage-gap`, `routing-gap`, `unreachable`} — the three §On no match prefixes. A
repeated gap (count ≥ 2) is the highest-value signal in the file: two sessions hit the same wall,
and the third will too. Brief ranks its "top unanswered questions" from this file; the audit-fix
remediation pass drafts trigger additions from `routing-gap` entries; `unreachable` entries are
the store-root/tool debts worth burning down first.

## Loop D (Escalation): Why Contradiction Velocity

Loops A/B/C are all additive-or-tune. No existing loop handles "this fact keeps getting challenged." Without Loop D (Escalation), a contested fact can survive indefinitely if each individual contradiction is evaluated in isolation — the pattern is only visible when you look across contributions. [learned: 2026-04-17]

```
[contradiction] arrives for fact X
  → Parliament checks _inbox/_completed/ for prior contradictions of fact X
    → if ≥2 contradictions in rolling 30-day window:
      → auto-tag fact X as [disputed] in knowledge file
      → open needs-review PR with all contradiction sources linked
      → CODEOWNERS added as PR reviewers (must approve before merge)
        → human resolves: either corrects the fact or closes with rationale
          → resolution recorded in _custodian/reports/
```

### Loop D (Escalation) Telemetry Schema

Parliament writes to `_custodian/reports/loop-d-disputes.json`:

```json
{
  "disputes": [
    {
      "fact_file": "knowledge/architecture.md",
      "fact_summary": "Service X uses protocol Y",
      "contradiction_count": 2,
      "first_seen": "2026-04-05",
      "latest": "2026-04-17",
      "status": "disputed",
      "pr_url": "https://..."
    }
  ]
}
```

---

## Relationship to Second Brain Loops

These loops are adapted from the Second Brain framework but maintained independently. They will evolve differently because:
- Multi-writer context introduces conflict resolution that single-owner doesn't need
- Trust calibration (whose corrections to weight more) has no single-owner equivalent
- Triage tuning (Loop C — Calibration) is only possible when multiple contributors create statistical signal

Improvements proven in the Hive Mind may be offered back upstream to the Second Brain skill when they generalize.
