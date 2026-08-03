# Design Goals: SGCM

This document captures the intent behind the SGCM skill. Read it before proposing changes. If a proposed change conflicts with something here, surface that conflict explicitly.

---

## Origin Story

Multi-agent workflows kept producing unverified output. Generator agents hallucinated file paths and claimed patterns existed in directories that did not contain them. Critic agents rubber-stamped findings without running verification commands. The mediator (main agent) had no structured way to distinguish confirmed facts from guesses.

SGCM was built to impose a structured verification protocol with confidence scoring so every claim has a paper trail.

---

## North Star

Layer structured, adversarial verification onto any task using composable cognitive roles.

---

## Scope

SGCM is an orchestration pattern. It defines how to structure multi-agent verification rounds, not what to build or review. It composes with task-specific skills: the task skill provides domain knowledge, SGCM provides verification discipline.

**What it covers:** role definitions, checklist output formats, confidence scoring rubric, threshold filtering, batching and parallelism guidance, re-critic rounds, and skill composition patterns.

**What it depends on:** Claude Code's Agent tool for subagent dispatch. Any task-specific skill to compose with (but works standalone too).

**What it leaves to others:** domain expertise, test execution, code review criteria, project management, build systems.

---

## Key Decisions

### 1. Four roles, not three

The Mediator is separate from the Critic.

**What drove it:** Critics are adversarial by design and optimize for finding faults. A critic-as-triage agent would over-correct, applying every finding regardless of practical impact. The mediator's job is pragmatic synthesis: weigh evidence from both generator and critic, spot-check key claims, and make final calls.

**What breaks if reversed:** Without a separate mediator, every critic finding gets treated as equally important and the skill becomes a nitpick amplifier.

---

### 2. Checklists, not prose

All role output uses structured checklist formats (FACT/EVIDENCE/RESULT, INSIGHT/IMPLICATION/SCOPE/CONFIDENCE, CHECK/CLAIM/EVIDENCE/CONFIDENCE/SEVERITY/VERIFY_CMD).

**What drove it:** The Checklist Manifesto principle -- experts fail from ineptitude (skipping steps), not ignorance. Prose lets you skip claims implicitly. A checklist makes every claim explicit and verifiable.

**What breaks if reversed:** Prose output is harder to cross-reference between stages, harder to filter by confidence, and lets agents hide uncertainty in fluent language.

---

### 3. Confidence thresholds at 75/60

The mediator acts on critic findings >= 75 and considers generator insights >= 60.

**What drove it:** Calibrated through use. 75 is high enough to exclude most false positives from critics but low enough to catch real issues. 60 for generator insights is lower because generator output is exploratory -- worth investigating even when uncertain.

**What breaks if reversed:** Lower thresholds flood the mediator with noise. Higher thresholds miss real issues that need investigation.

---

### 4. Mediator is always the main agent

The mediator is never dispatched as a subagent.

**What drove it:** The mediator needs full context of all checklists from all stages to make coherent triage decisions. Subagents have isolated context. A mediator-as-subagent would make decisions without seeing the full picture.

**What breaks if reversed:** The mediator makes triage decisions based on partial information, potentially contradicting findings from checklists it never saw.

---

## What This Skill Is Not

- Not a code review tool. Compose SGCM with a review skill for that.
- Not a test framework or test runner. It verifies claims, not code correctness.
- Not a project management workflow. It has no concept of sprints, tickets, or deadlines.
- Not a replacement for domain expertise. SGCM structures verification; domain skills provide what to verify.
- Not a quality gate. It surfaces findings with confidence scores; humans decide what to act on.

---

## Known Limitations

- **Token-heavy for small tasks.** The four-stage overhead only pays for itself on non-trivial work. For a single-file change, `/sgcm/cm` is usually sufficient.
- **Confidence scoring is subjective.** The rubric provides anchors (10-100 with labeled thresholds), but two critics may score the same finding differently.
- **Parallel agent count must be managed manually.** No auto-scaling -- the operator decides how many scouts, generators, and critics to dispatch.
- **Assumes parallel subagent dispatch.** The skill assumes Claude Code's Agent tool supports parallel subagent execution. In environments without this capability, stages run sequentially (still works, just slower).

---

## Version History

| Version | What Changed | What Drove It |
|---------|-------------|---------------|
| 0.1.0 | Initial release. Fixed broken `references/` paths in the gcm/cm/m sub-skills (they resolved relative to their own skill dirs, where no `references/` existed — now point at `../sgcm/references/`); replaced the root-level symlink with a real directory under `skills/sgcm/`. Normalized invocation syntax to `/sgcm:level` in README. Descriptions reworded to lead with "Use when" triggers per skill-authoring guidance. | First public release of the orchestration pattern |
