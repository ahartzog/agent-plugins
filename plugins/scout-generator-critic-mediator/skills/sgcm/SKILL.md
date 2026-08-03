---
name: sgcm
description: >
  Use when the user asks for "sgcm", "generator critic mediator", "scout generate critic mediate",
  "adversarial verification", "parallel verify and fix", "multi-agent review rounds",
  "checklist verification", or "orchestrate work through scout/generate/critic/mediate stages" --
  or when a task needs discovery plus verified output. Default when invoking /sgcm with no level
  qualifier. Composable -- invoke alongside any other skill.
---

# SGCM: Scout-Generator-Critic-Mediator

**Active stages: Scout -> Generator -> Critic -> Mediator (full loop)**

A composable orchestration pattern that layers structured verification rounds onto any task.
Invoke alongside other skills -- SGCM defines HOW to orchestrate; the task skill defines WHAT to do.

## Level Selection

This is the **full loop** (all four stages). For narrower scopes, use:

| Need | Invocation | Stages |
|------|-----------|--------|
| Full discovery loop | `/sgcm` (this skill) | Scout -> Generator -> Critic -> Mediator |
| Build and verify | `/sgcm:gcm` | Generator -> Critic -> Mediator |
| Check existing work | `/sgcm:cm` | Critic -> Mediator |
| Just triage findings | `/sgcm:m` | Mediator only |
| Re-verify after fixes | Tier R | Repeat Critic -> Mediator |

Cannot skip stages. Must include Mediator. Prepend only in order.

## The Four Roles

Each role is a **cognitive posture** -- a different attention pattern applied to the same information.
Not job titles. Not left-brain/right-brain stereotypes. All analytical, in different directions.

| Role | Posture | Entropy | Reasoning | Core Question |
|------|---------|---------|-----------|---------------|
| **Scout** | Faithful reporter | Low | Observational | "What IS?" |
| **Generator** | "Yes, and..." | High | Inductive | "What does this IMPLY?" |
| **Critic** | "Prove it" | Low | Deductive | "What's WRONG?" |
| **Mediator** | Journal editor | Medium | Abductive | "What do we DO?" |

**Scout** -- catalogs reality with direct evidence. Heavy tool use: grep, glob, read, code search,
CLAUDE.md files, READMEs. Outputs facts, not opinions. No assumptions.

**Generator** -- the divergent explorer. High openness, low threshold for connections. In a build task:
produces output. In a review: finds patterns, extrapolates implications, connects dots across
boundaries. "This fix to the retry logic suggests the same pattern might exist in three other
connectors." The role that says "yes, and..." -- not taking things at face value, but thinking about
what they imply.

**Critic** -- the convergent verifier. High threshold, demands proof. Does not take generator claims
at face value. Adversarial by design. "You said this pattern exists in three connectors -- show me.
I checked and it's only in two." Where the generator opens possibility space, the critic collapses
it to verified truth.

**Mediator** -- journal editor, not courtroom judge. Spot-checks claims from BOTH generator and
critic (trusts neither fully). Runs targeted verification commands. Weighs verified evidence,
triages severity, distinguishes real issues from noise. Makes final calls and applies changes.

## Communication Protocol

Each role produces a **checklist, not prose**. The Checklist Manifesto principle: make every claim
explicit and verifiable. Binary (pass/fail) where possible, scored where ambiguous.

See `references/checklists.md` for the three structured output formats and the confidence scoring
rubric (10-100 scale with threshold filtering).

## Composing with Other Skills

SGCM layers on top of any loaded skill:

1. Invoke `/sgcm` -- loads orchestration pattern
2. Invoke the task skill (e.g., `/executing-plans`, `/code-review`) -- loads task instructions
3. Follow BOTH -- execute the task using SGCM rounds

The task skill provides the WHAT. SGCM provides the HOW.

## Execution Pattern

**Scout stage**: Launch Explore agents or run tool commands directly. Produce Scout Checklists.
Feed results to subsequent stages as context.

**Generator stage**: Launch parallel agents with generator posture prompts. Each produces a
Generator Checklist with insights, implications, and confidence scores.

**Critic stage**: Launch parallel agents with critic posture prompts. Each reads the work product
and produces a Critic Checklist with PASS/FAIL per claim, confidence scores, and VERIFY_CMDs.

**Mediator stage**: Main agent synthesizes all checklists. Runs VERIFY_CMDs for findings above
confidence threshold. Triages severity. Applies fixes. Optionally re-runs critic stage ("Tier R").

See `references/orchestration.md` for batching, parallelism, and re-critic round guidance.
See `references/role-prompts.md` for copy-pasteable subagent prompt templates.

## Additional Resources

- **`references/role-prompts.md`** -- full subagent prompt templates per role
- **`references/checklists.md`** -- structured output formats, scoring rubric, threshold guidance
- **`references/orchestration.md`** -- parallel vs sequential, batching, re-critic, worked example
