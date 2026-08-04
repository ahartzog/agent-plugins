---
layer: PROTOCOL
type: triage-policy
description: "Rules Parliament uses to route contributions: fast path vs deliberation, auto-merge vs flag"
last_updated: 2026-04-16
codeowners: (read from hive.yml)
---

# Triage Policy

This file governs how Parliament routes contributions from the inbox into the knowledge base. Full Parliament runbook: `custodian-workflow.md`.

---

## Contribution Categories

Each inbox contribution carries a tag that determines its processing path. The Archivist validates and may re-tag mislabeled contributions before routing.

| Tag | Category | Path | Rationale |
|---|---|---|---|
| `[link]` | New document link | Fast (auto-merge) | Additive, verifiable by URL existence |
| `[person]` | New person/role | Fast (auto-merge) | Additive, low risk of inaccuracy |
| `[tracker]` | New tracker/channel | Fast (auto-merge) | Additive, verifiable |
| `[status]` | Status update | **Deliberation** | High staleness risk — requires source citation or existing fact check |
| `[correction]` | Factual correction with source | **Deliberation** | Modifies existing knowledge — source must be verified |
| `[architecture]` | Architectural claim | **Deliberation** | Strategic implications, may contradict existing design |
| `[process]` | Process/principle change | **Deliberation** | Affects how people work — requires consensus |
| `[contradiction]` | Contradiction of existing fact | **Deliberation** | Directly conflicts with current knowledge |
| `[strategy]` | Strategic/priority recommendation | **Deliberation** | Opinion-laden, requires authority validation |
| `[meta]` | Observation about skill/PROTOCOL | **Deliberation** + CODEOWNERS | Skill-refinement signal — targets the protocol layer, not knowledge. Routed to deliberation AND tagged for CODEOWNERS review regardless of Chancellor verdict. [learned: 2026-04-17] |

**Expected split:** ~80% of contributions take the fast path. ~20% go through deliberation. [learned: 2026-04-16]

---

## Fast Path

**Categories:** `[link]`, `[person]`, `[tracker]`

```
Raw contribution
  → Archivist: format, annotate, determine target file
  → Open auto-merge PR
  → Tag reviewer
  → PR merges automatically after CI passes
```

**Archivist responsibilities on fast path:**
1. Validate format and frontmatter
2. Add `[learned: YYYY-MM-DD]` annotation
3. Determine target knowledge file
4. Format entry to match existing file voice and style
5. Check for duplicates — if already present, skip with a note
6. Open the batch PR

---

## Deliberation Path

**Categories:** `[status]`, `[correction]`, `[architecture]`, `[process]`, `[contradiction]`, `[strategy]`, `[meta]`

```
Raw contribution
  → Parallel independent critics (no cross-talk):
      Skeptic  → structured checklist (PASS/FAIL per claim)
      Archivist → structured checklist (PASS/FAIL per standard)
      Cartographer → structured checklist (PASS/FAIL per structural fit)
  → Reviser: builds formatted entry from raw contribution + all three checklists
  → Chancellor: reviews Reviser output + critic findings
      → MERGE  → canonical disposition rule (custodian-workflow.md §4.3):
                 clean MERGE → auto-merge batch PR; MERGE with a
                 high-confidence objection → needs-review PR (CODEOWNER gate)
      → REVISE → back to Reviser (max 2 revision rounds)
      → REJECT → rejection PR (closed immediately, reasoning in description)
      → ESCALATE → PR with escalation label + CODEOWNER tag
```

**Revision gate:** Max 3 total Reviser attempts (initial + 2 revisions). If Chancellor is still unsatisfied after 3, escalate to human review. [learned: 2026-04-16]

---

## Write Operations

A tag implies not just a routing path but a **write operation** — what happens to the target
knowledge file. Stating it explicitly is what guarantees the annotations `knowledge-schema.md`
documents actually get written (an annotation with no writer is a documented lie):

| Tag | Operation |
|---|---|
| `[link]` `[person]` `[tracker]` | **ADD** — append a new entry |
| `[status]` | **SUPERSEDE** when a prior status line for the same subject exists (paired edit: mark it `[superseded: date, reason]`, add the new one); plain **ADD** for a first observation |
| `[correction]` | **SUPERSEDE** — same paired edit; the old value stays visible under its marker |
| `[contradiction]` | **ANNOTATE** — when Loop D fires (`custodian-workflow.md` §4.1.05), add `[disputed: date]` to the challenged fact; the fact itself is not changed until a human resolves |
| `[architecture]` `[process]` `[strategy]` | **ADD** (or SUPERSEDE when explicitly replacing a prior entry) |
| `[meta]` | **No knowledge write** — targets the protocol layer; surfaced to CODEOWNERS regardless of verdict, and protocol changes land upstream via a CODEOWNER PR |

There is deliberately **no DELETE**: a git-audited knowledge base retires facts by supersession,
never by removal — history is the audit trail.

## Auto-Merge Rules

Parliament enables GitHub auto-merge (`gh pr merge --auto --squash`) on every batch PR it creates. The PR merges automatically once all required status checks pass (CI, policy-bot, corroborate). This is the default for all knowledge contributions that clear the fast path or Chancellor approval.

This section restates the **canonical MERGE disposition rule** in `custodian-workflow.md` §4.3 — that rule governs if the two ever disagree. A contribution qualifies for the auto-merge batch PR when ALL of the following are true:

1. Category is `[link]`, `[person]`, or `[tracker]` — OR Chancellor verdict is a clean MERGE (no high-confidence critic objections outstanding)
2. Archivist checklist passes (format valid, annotation present, target file identified)
3. No duplicate detected in the target knowledge file

A contribution is **not** auto-merged and requires CODEOWNER review when:
- Category is deliberation-path and the verdict is anything other than a clean MERGE
- Chancellor verdict is MERGE but a high-confidence critic objection is outstanding
- Sentinel quarantines the contribution (PII/credential match, or a Hive-declared gate extension blocks it)
- Archivist cannot determine the correct target file
- Contribution was previously rejected and resubmitted (requires human judgment)

---

## PR Types and Behavior

| PR Type | Trigger | Auto-merge? |
|---|---|---|
| **Batch merge** | All fast-path + clean-MERGE deliberation in this run | Yes — `gh pr merge --auto --squash` |
| **Needs review** | MERGE with a high-confidence objection outstanding, or Loop D fired (§4.1.05) | No until CODEOWNER approves (auto-merge armed) |
| **Rejected** | Chancellor rejects after deliberation | PR opened then closed |
| **Escalated** | Chancellor deadlocked or contribution too ambiguous | No — requires CODEOWNER + discussion |

Parliament produces **one PR per run** for fast-path contributions, not one per contribution. Individual traceability lives in `_inbox/_completed/` reconciliation notes.

---

## Archivist Re-Tagging Responsibility

The Archivist is the first agent to see every contribution on both paths. Before routing, it must:

1. Validate the contributor's tag against the category definitions above
2. If the tag appears incorrect, re-tag with a note: `[re-tagged from [link] to [correction]: this modifies existing knowledge, not additive]`
3. Apply the correct path based on the re-tagged category
4. Record the re-tag in the reconciliation notes

The Archivist's re-tag is authoritative for routing. The contributor's original tag is recorded for audit purposes.

---

## Loop C (Calibration): Triage Policy Refinement

This policy is not static. Loop C (Calibration) monitors approval/rejection ratios and triggers policy refinement:

Approval/rejection ratios trigger policy refinement. See `PROTOCOL/learning-loops.md` Loop C (Calibration) for the threshold and mechanism. Refinements require a CODEOWNERS PR against this file.

---

## Human Direct-PR Path

Parliament handles the agent-driven flow (inbox → critics → PR). The direct-PR path handles the human-driven flow: a contributor branches, edits `knowledge/` by hand, and opens a PR.

**When to use it:**
- Authoring or replacing a knowledge file wholesale (a finished doc, an ingested external artifact)
- Deliberate restructures that span multiple files
- Edits the contributor wants in their own voice without Archivist re-formatting
- Any change where fragmenting the contribution into inbox entries would destroy its coherence

**When not to use it:**
- Capturing a single fact discovered mid-conversation — use the inbox, Parliament will triage
- Anything an agent is writing on the user's behalf — agents do not open `knowledge/` PRs

**Gate:**
- CODEOWNER review is **required**. No auto-merge on the direct-PR path, ever. This is the human analogue of Parliament's Chancellor verdict.
- CI still runs: schema lint, size budget check. A critic-CI job (Skeptic / Archivist / Cartographer) runs against the diff and posts an advisory review comment. Critic verdict is informational; CODEOWNERS decide.
- On merge, Parliament is notified via a post-merge job that appends a reconciliation note to `_inbox/_completed/` so the direct-PR path shows up in the same audit trail as inbox contributions.

**Rationale:** The inbox optimizes for *capture-in-flight* and is the wrong ergonomics for *deliberate authoring*. Forcing a finished document through fragmented inbox entries is ceremony, not safety. The direct PR preserves the author's voice and coherence; the CODEOWNER gate preserves the collective-ownership principle. [learned: 2026-04-19]

---

## Quarantine Rules

Contributions are moved to `_inbox/_quarantine/` (not processed) when:

- Prompt injection pattern detected
- Author attribution missing or unverifiable
- Contribution contains personal attacks or PII beyond professional attribution

Quarantine is not rejection — it is escalation for human review, surfaced to CODEOWNERS via `/apiary audit` (Sentinel Retrospective).
