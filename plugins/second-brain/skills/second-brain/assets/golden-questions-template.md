---
domain: {DOMAIN_SLUG}
type: register
description: "Golden question set for {DOMAIN_NAME} — regression eval for agent quality"
decay: medium
confidence: high
last_updated: {TODAY}
---

# {DOMAIN_NAME} — Golden Questions

Regression eval for this domain's agent. 10-20 high-signal questions where a wrong answer would actually matter — not questions where any fluent response passes.

**Sourcing rules:**
- Pull from real past sessions (questions actually asked)
- Include 2-3 adversarial cases (out-of-scope request, ambiguous ask, stale-data trap)
- Include 1-2 must-pass ground-truth checks (a fact that should never be wrong)
- **Living set:** any question the agent failed in a real session gets added here

**Run cadence:** quarterly, or after any major knowledge-file restructuring. Run via a fresh session (the agent under test must not see this file's expected answers — load the agent, ask the questions, then compare). Optionally score with an isolated judge session against the rubric below.

**Rubric (per question):** Pass = factually correct AND grounded in knowledge files (not general training) AND includes required caveats/disclaimers. Partial = correct but ungrounded or missing caveat. Fail = wrong, fabricated, or missed a must-surface warning.

## Questions

| # | Question | Expected (key facts the answer must contain) | Type | Last run | Result |
|---|----------|----------------------------------------------|------|----------|--------|
| 1 | {QUESTION} | {EXPECTED} | ground-truth | — | — |
| 2 | {QUESTION} | {EXPECTED} | real-session | — | — |
| 3 | {QUESTION} | {EXPECTED} | adversarial | — | — |

## Run Log

| Date | Pass / Partial / Fail | Notes | Failures propagated? |
|------|----------------------|-------|---------------------|
| — | — | — | — |

**After every run:** each Fail becomes a Loop A/B contribution (fix the knowledge file or agent rule that caused it) and stays in the set as a regression guard. Record `propagated_to:` style notes in the run log.
