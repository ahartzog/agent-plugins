---
name: cm
description: >
  Use when reviewing PRs, auditing docs, checking code, or validating
  any existing artifact without producing new content. SGCM
  Critic-Mediator level -- verify existing work product, then triage.
---

# SGCM: Critic -> Mediator

**Active stages: Critic -> Mediator**

Scout and Generator stages are skipped -- use this when work product already exists and you
need to verify it. The most common level for code review, PR checks, and doc audits.

For the full loop with discovery, use `/sgcm`. To also produce work: `/sgcm:gcm`. To just triage: `/sgcm:m`.

## The Two Active Roles

| Role | Posture | Entropy | Reasoning | Core Question |
|------|---------|---------|-----------|---------------|
| **Critic** | "Prove it" | Low | Deductive | "What's WRONG?" |
| **Mediator** | Journal editor | Medium | Abductive | "What do we DO?" |

**Critic** -- the convergent verifier. High threshold, demands proof. Adversarial by design.
"You said this pattern exists in three connectors -- show me. I checked and it's only in two."

**Mediator** -- journal editor, not courtroom judge. Spot-checks claims from the critic
(trusts nothing fully). Runs targeted verification commands. Triages severity, distinguishes
real issues from noise. Makes final calls and applies changes.

## Communication Protocol

Each role produces a **checklist, not prose**. See `../sgcm/references/checklists.md` for formats and
the confidence scoring rubric (10-100 scale with threshold filtering).

## Execution Pattern

**Critic stage**: Launch parallel agents with critic posture prompts. Each reads the work product
and produces a Critic Checklist with PASS/FAIL per claim, confidence scores, and VERIFY_CMDs.

Parallelize by lens when the artifact is large:
- Critic A: structural accuracy (do files/dirs exist?)
- Critic B: content accuracy (are APIs/examples correct?)
- Critic C: convention compliance (style rules, naming, etc.)

8-15 checks per critic is ideal.

**Mediator stage**: Main agent synthesizes all Critic Checklists. Runs VERIFY_CMDs for findings
>= 75 confidence and HIGH/MEDIUM severity. Triages into: confirmed fix, false positive,
needs-more-investigation. Applies fixes. Optionally re-runs critic stage ("Tier R").

See `../sgcm/references/orchestration.md` for batching, parallelism, and re-critic round guidance.
See `../sgcm/references/role-prompts.md` for copy-pasteable subagent prompt templates.
