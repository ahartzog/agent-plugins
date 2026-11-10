---
type: protocol
description: "The five learning loops as vocabulary: what each one names, and where the operating protocol covers it. Demand-loaded by audit, wrap, and custodian workflows"
last_updated: 2026-11-09
---

# Learning Loops

Since 3.0.0 the rules an agent follows during a session are in `protocol/operating-protocol.md`, which is the only protocol file operate mode loads. This file keeps the five loop names, because audit, wrap, and custodian workflows use them to label what they find. Where this file and the operating protocol differ, the operating protocol wins. Design rationale for the loops: `references/learning-loops.md`.

## What each loop names

| Loop | What it names | Where the operating protocol covers it |
|---|---|---|
| **A - Corrections** | The owner corrects a fact or a behavior | A fact: "When a fact changes". A behavior: "Changing how an agent behaves" |
| **B - Discoveries** | The session learns something a future session needs | "Capture" and "Match the write to the commitment" |
| **C - Custodian** | A class of problem is found that the periodic health check should catch next time | Not an in-session rule. Custodian and audit workflows own it |
| **D - Contradictions** | New information conflicts with what a file says | "When a fact changes", the conflict rule |
| **E - Process** | An agent's own instructions produced a bad answer or got in the way | "Changing how an agent behaves" |

Two things an agent might expect to find here are gone on purpose:

- **No end-of-session ritual.** Sessions rarely end cleanly. Capture happens in the turn that produced the knowledge, each write is reported with a `Saved:` line, and "is everything saved?" is answered by re-reading the conversation against the files.
- **No per-loop prompt format.** Anything that needs the owner's yes is a numbered item in the reply.

## Loop C - the periodic health check

When the owner catches a problem the custodian missed: fix it, name the class of problem, and propose a check for that class in the hub's `custodian-workflow.md`. Changing the checklist needs a yes.

Checks that have earned their place in practice, in order of yield:

1. **Derived values.** For each input that many figures hang on (a price, a rate, a count), find the figures computed from it and confirm they match its current value.
2. **Copies.** A value that appears as state in more than one file. The fix is one owner and links.
3. **Open conflicts.** Every `[disputed:]` with its age.
4. **Commitments.** Open checkbox tasks past their date, and tasks that carry a date nobody set.
5. **Oldest verifications.** The volatile facts whose `[verified:]` date is oldest, re-checked against their source.
6. **Link integrity.** `references/mode-audit.md` § Link Graph Health.

## Telemetry

A custodian or audit run may append one row to `_reports/loop-health.json`. Sessions do not write to it.

```json
{
  "date": "YYYY-MM-DD",
  "run_type": "custodian",
  "facts_corrected_by_owner": 0,
  "save_checks_requested": 0,
  "deadlines_missed": 0,
  "copies_found": 0,
  "derived_values_stale": 0,
  "open_conflicts": 0,
  "custodian_checks_total": 0
}
```

The first three are outcomes and matter most: how often the owner had to correct the knowledge base, how often they had to ask whether something was saved, and how many hard deadlines passed without being surfaced. A healthy system drives those toward zero. Counts of how much was written say nothing about health.
