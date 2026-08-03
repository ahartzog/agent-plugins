---
name: gcm
description: >
  Use when building new work product that needs adversarial verification, or when
  context is already established and discovery is unnecessary. SGCM
  Generator-Critic-Mediator level -- skips Scout (ground truth already known).
---

# SGCM: Generator -> Critic -> Mediator

**Active stages: Generator -> Critic -> Mediator**

Scout stage is skipped -- use this when ground truth is already established (you know the codebase,
the PR is already open, the context is clear). Jumps straight to producing and verifying.

For the full loop with discovery, use `/sgcm`. For narrower scopes: `/sgcm:cm` or `/sgcm:m`.

## The Three Active Roles

| Role | Posture | Entropy | Reasoning | Core Question |
|------|---------|---------|-----------|---------------|
| **Generator** | "Yes, and..." | High | Inductive | "What does this IMPLY?" |
| **Critic** | "Prove it" | Low | Deductive | "What's WRONG?" |
| **Mediator** | Journal editor | Medium | Abductive | "What do we DO?" |

**Generator** -- the divergent explorer. High openness, low threshold for connections. In a build task:
produces output. In a review: finds patterns, extrapolates implications, connects dots across
boundaries.

**Critic** -- the convergent verifier. High threshold, demands proof. Does not take generator claims
at face value. Adversarial by design.

**Mediator** -- journal editor, not courtroom judge. Spot-checks claims from BOTH generator and
critic (trusts neither fully). Runs targeted verification commands. Makes final calls and applies changes.

## Communication Protocol

Each role produces a **checklist, not prose**. See `../sgcm/references/checklists.md` for formats and
the confidence scoring rubric (10-100 scale with threshold filtering).

## Execution Pattern

**Generator stage**: Launch parallel agents with generator posture prompts. Each produces a
Generator Checklist with insights, implications, and confidence scores.

**Critic stage**: Launch parallel agents with critic posture prompts. Each reads the work product
and produces a Critic Checklist with PASS/FAIL per claim, confidence scores, and VERIFY_CMDs.

**Mediator stage**: Main agent synthesizes all checklists. Runs VERIFY_CMDs for findings above
confidence threshold. Triages severity. Applies fixes. Optionally re-runs critic stage ("Tier R").

See `../sgcm/references/orchestration.md` for batching, parallelism, and re-critic round guidance.
See `../sgcm/references/role-prompts.md` for copy-pasteable subagent prompt templates.
