---
type: protocol
description: "Five learning loops that drive Second Brain self-improvement — when to contribute (Self-Awareness Protocol) and operational rules for how contributions are applied"
last_updated: 2026-07-30
---

# Learning Loops — Operational Protocol

<CRITICAL>
This protocol defines both WHEN to contribute (the Self-Awareness Protocol below) and HOW contributions are applied (the loops and triage rules that follow). It is the complete operating discipline — agent definitions do not restate any of it. It reaches the session via Operate mode (`references/mode-operate.md`), which agent definitions bootstrap.

Check the agent's `auto_contribute` setting (in the agent definition file's YAML frontmatter):
- `true` → write auto-eligible changes to knowledge files directly. Report what changed at session end.
- `false` (or absent) → surface each proposed change to the user. Apply only if approved.

Contradictions (Loop D), custodian evolution (Loop C), and process/agent-definition changes (Loop E) ALWAYS prompt regardless of setting.

Design rationale and failure mode analysis: `references/learning-loops.md`.
</CRITICAL>

---

## Self-Awareness Protocol — When to Contribute

Two phases, both in-session. **If either is skipped, the loops degrade silently.**

Staleness inventory (scanning frontmatter for overdue `review_by`, drifted `last_updated`) is **not** part of this protocol — it is an audit/custodian job, not something to run at the head of every session. See `references/mode-audit.md`.

### Phase 1 — Continuous: The Contribution Reflex

At every natural breakpoint — after answering a question, loading a document, or completing a task — evaluate: **did I just learn something a future session would benefit from knowing?**

Trigger signals (any one warrants a contribution):
- Loaded a document, API, or tool the knowledge files don't mention
- Discovered a person's role, relationship, or decision authority
- Found a workaround, quirk, or limitation not in the agent's Domain Context
- The user corrected a factual claim or behavioral pattern
- A status, timeline, balance, or dependency changed from what the knowledge files say
- Encountered a link, account, resource, or contact not indexed anywhere
- Two sources disagreed on a fact

**This is a structural obligation, not optional self-reflection.** The difference between a static knowledge base and a compounding one is whether this reflex fires reliably.

### Phase 2 — Task-Completion Gate

**This replaces an end-of-session gate.** Sessions end unpredictably — closed window, compacted context, idle timeout. Treat every completed task as a contribution checkpoint:

1. Check the trigger signals. If none fire, move on.
2. Apply or propose immediately per `auto_contribute`. Do not defer to "session end."
3. Run the Loop E retrospection questions (below) — they gate task completion, not just session end.
4. In multi-task sessions, each task gets its own check. Contributions are continuous, not batched.

At any natural pause where the user might disengage:

5. **Inventory:** if `auto_contribute: true`, confirm all writes landed. If `false`, batch remaining proposals: "I have N updates from this session — want to review?"
6. **Fresh-session test:** if a new session loaded only these knowledge files tomorrow, would it have the full picture?

---

## Loop A: Corrections → Agent Rules

User corrects domain-specific behavior → determine destination per triage policy → apply correction to agent Rules/Principles section, workflow file, or knowledge file. Add `propagated_to: {target-file}` to the feedback memory file's frontmatter.

**Behavior:**
- `auto_contribute: true`: apply the rule immediately, report at session end
- `auto_contribute: false`: surface proposed rule text and target file, wait for approval

The agent file is the enforcement point. Memory is the audit trail.

---

## Loop B: Discoveries → Knowledge Files

Session discovers new fact (workaround, tool limitation, API quirk, status update) → determine scope and target per triage policy → write to appropriate knowledge file with `[learned: YYYY-MM-DD]` annotation. When the fact records a genuine decision, add `[decided: <who>, YYYY-MM-DD]` per `protocol/knowledge-schema.md`.

**Behavior:**
- `auto_contribute: true`: write to knowledge file immediately, report at session end
- `auto_contribute: false`: surface proposed content and target file, wait for approval

**Scope routing:**
| Scope | Target |
|---|---|
| Single-agent | Agent's Domain Context or domain knowledge file |
| Cross-domain | Hub `## Shared Context` or shared knowledge file |
| Upstream gap | Local knowledge file + note for skill/MCP improvement |

Read the target file before writing — pre-read prevents contradiction pollution. Never leave discoveries only in memory — memory gets compacted. Never silently overwrite — changed facts get `[superseded: YYYY-MM-DD, reason]` on the old value.

---

## Loop C: Quality → Custodian Self-Improvement

When the user manually catches a vault issue the custodian missed → fix the issue → identify the CLASS of issue → propose adding a new check to `custodian-workflow.md`.

Loop C ALWAYS prompts regardless of `auto_contribute` setting. Custodian evolution is a structural change that requires user judgment.

**Data tracking:** Each custodian run appends to `_reports/loop-health.json`:
```json
{
  "date": "YYYY-MM-DD",
  "corrections_propagated": 0,
  "corrections_pending": 0,
  "discoveries_written": 0,
  "contradictions_detected": 0,
  "process_revisions_proposed": 0,
  "custodian_checks_total": 0,
  "custodian_checks_added_this_run": 0
}
```

When custodian check count has not grown in 30+ days and sessions are active, surface a prompt: "The custodian checklist hasn't grown recently. Are there issue patterns you've been catching manually?"

---

## Loop D: Contradiction Velocity → Auto-Flag

When a session writes a fact that contradicts an existing knowledge file entry:

1. Tag the existing entry with `[disputed: YYYY-MM-DD]`
2. Add both the old and new claims with their sources to a `## Disputed Facts` section in the knowledge file
3. Surface the contradiction to the user immediately (ALWAYS prompt, regardless of `auto_contribute` setting)

**Velocity detection:** If the same fact has been contradicted 2+ times within 30 days (tracked via `[disputed:]` annotations), escalate: surface in the next custodian run as a Critical finding and add to `_reports/loop-health.json` contradictions counter.

Loop D always prompts regardless of `auto_contribute`. Contradictions are judgment calls.

---

## Loop E: Process Retrospection → Agent Definition

Loops A-D are reactive — they fire when the user corrects something or a session stumbles onto a fact. Loop E is **proactive**: at every task-completion gate, the agent reviews its own instructions against what just happened.

**The four questions (evaluate at each task-completion gate):**
1. Did my instructions produce a good answer, or did I have to work around them?
2. Did the user correct my approach, tone, or framing — not just facts?
3. Did I discover a judgment frame, tradeoff, or heuristic that isn't in my agent file?
4. Did I follow a rule that felt wrong, or skip a step that was prescribed?

If any answer is yes → propose a revision to the agent definition file. **Loop E ALWAYS prompts** — changes to how an agent decides require user judgment.

**Eviction discipline:** a rule the agent had to work around is a bug in the rule. Propose revising or removing it — don't accumulate dead rules. Agent files should only retain instructions that produce good outcomes (skill-library discipline: procedures stay only while they earn their place).

**Error classification:** when a session produced a wrong or corrected answer, classify it before routing: *knowledge gap* (→ Loop B: add the fact), *stale data* (→ Loop B: supersede + fix decay rate), *wrong judgment* (→ Loop E: revise principle, with the failure as a worked example), *tool failure* (→ Loop B: document workaround + upstream note).

**Form of the fix:** prefer principles over procedures. Teach the agent how to decide, not what to do. If the lesson came from a real failure, embed it as a worked example — examples survive; abstract rules get rationalized away. Red flag: adding a numbered procedure for what is actually a judgment call.

**Tracking:** count proposals in `_reports/loop-health.json` (`process_revisions_proposed`). An agent that hasn't proposed a Loop E revision in 60+ days of active use is either mature or asleep — the custodian should ask which.

---

## Triage Rules

Contribution routing follows `protocol/triage-policy.md`. The triage policy defines which types of knowledge changes are auto-eligible vs always-prompt:

| Tag | Category | Auto when `auto_contribute: true`? | Rationale |
|---|---|---|---|
| `[correction]` | Factual correction (Loop A) | Yes | Corrects known error |
| `[link]` `[person]` `[tracker]` | Additive discovery (Loop B) | Yes | Additive, low risk |
| `[status]` `[discovery]` | Status/workaround (Loop B) | Yes | Time-sensitive or operational |
| `[architecture]` `[process]` | Strategic/process claim (Loop E territory) | No — always prompt | Strategic implications |
| `[contradiction]` | Contradicts existing fact (Loop D) | No — always prompt | Requires human judgment |
| `[custodian]` | New custodian check (Loop C) | No — always prompt | Structural change |

When `auto_contribute: true`: auto-eligible items are written directly; always-prompt items are surfaced.
When `auto_contribute: false`: ALL items are surfaced to the user for approval before writing.

---

## Infrastructure

| Component | Purpose |
|---|---|
| Agent frontmatter `auto_contribute:` | `true\|false` — controls contribution behavior per agent |
| Self-Awareness Protocol (above) | Contribution reflex + task-completion gate (incl. Loop E questions) — loaded by Operate mode, never restated in agent files |
| `protocol/triage-policy.md` | Routing rules for contribution types |
| `protocol/knowledge-schema.md` | Required frontmatter for knowledge files |
| Agent Contribution Gate (via Operate mode) | Determines write-directly vs prompt-user behavior |
| `propagated_to:` frontmatter | Tracks feedback propagation (Loop A) |
| `[learned:]` / `[review-by:]` annotations | Provenance and staleness (Loop B) |
| `[decided: <who>, …]` annotations | Epistemic provenance — records that a decision was made and by whom (human or agent); author-time |
| `[disputed:]` annotations | Contradiction tracking (Loop D) |
| `_reports/loop-health.json` | Quantitative loop telemetry (Loops C/E) |
| `_reports/custodian-*.md` | Custodian run reports |
| `.staleness-manifest.json` | Mechanical drift detection for sourced files |
| Hooks (optional, L4) | Deterministic enforcement of nudges and raw-layer protection — see `references/enforcement-hooks.md` |
