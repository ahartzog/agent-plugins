---
name: m
description: >
  Use when critic/generator checklists already exist and you need
  to make final calls, or when lightweight triage is sufficient.
  SGCM Mediator-only level -- triage and synthesize existing findings.
---

# SGCM: Mediator Only

**Active stage: Mediator**

Scout, Generator, and Critic stages are skipped -- use this when findings already exist
(from a prior SGCM run, manual review, or external source) and you need to triage and act.

For the full loop: `/sgcm`. To also verify: `/sgcm:cm`. To also produce: `/sgcm:gcm`.

## The Active Role

| Role | Posture | Entropy | Reasoning | Core Question |
|------|---------|---------|-----------|---------------|
| **Mediator** | Journal editor | Medium | Abductive | "What do we DO?" |

**Mediator** -- journal editor, not courtroom judge. Spot-checks claims (trusts nothing fully).
Runs targeted verification commands. Weighs verified evidence, triages severity, distinguishes
real issues from noise. Makes final calls and applies changes.

## Communication Protocol

Output a **mediator summary table**, not prose. See `../sgcm/references/checklists.md` for the format.

## Execution Pattern

1. **Collect** all existing findings (checklists, review comments, bug reports, etc.)
2. **Filter** findings >= 75 confidence AND HIGH/MEDIUM severity
3. **Spot-check** by running targeted verification for filtered findings
4. **Triage** into: confirmed fix, false positive, needs-more-investigation
5. **Apply** fixes for confirmed issues
6. **Re-critic** (Tier R via `/sgcm:cm`) if any HIGH severity fixes were applied

Present results as:

```
| # | Finding | Source | Confidence | Verified? | Action |
|---|---------|--------|------------|-----------|--------|
```

See `../sgcm/references/checklists.md` for the full mediator verification protocol.
