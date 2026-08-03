# Learning Loops — The Reinforcement Model

This is the most important document in the Second Brain skill. Everything else — the templates, the audit checks, the maturity model — exists to serve these loops. If the loops work, the system compounds in value over time. If they don't, you have a static knowledge base that decays.

## Why This Matters

An AI assistant without learning loops has amnesia. Every session starts from zero context, and every correction you give evaporates when the session ends. You end up correcting the same mistakes, rediscovering the same workarounds, and manually catching the same structural issues — forever.

Learning loops fix this by creating **closed feedback circuits** where every interaction that produces new knowledge has a defined path back into the system's permanent state. The knowledge isn't just captured — it's placed where it will be loaded and enforced automatically in future sessions, without relying on the user to remember or re-state it.

The Second Brain has five loops, each addressing a different class of knowledge that sessions produce:

```
┌──────────────────────────────────────────────────────┐
│                   THE REINFORCEMENT MODEL              │
│                                                        │
│   Loop A: Corrections ──→ Agent Rules                  │
│   "You told me I was wrong. I won't do that again."    │
│                                                        │
│   Loop B: Discoveries ──→ Knowledge Files              │
│   "We found something. It's written down forever."     │
│                                                        │
│   Loop C: Quality ──→ Custodian Self-Improvement       │
│   "You caught it manually. Next time it's automatic."  │
│                                                        │
│   Loop D: Contradictions ──→ Disputed Facts            │
│   "Two sources disagree. Surface it, don't bury it."   │
│                                                        │
│   Loop E: Process Retrospection ──→ Agent Definitions  │
│   "My own instructions failed me. Fix the instrument." │
│                                                        │
│   All five share one principle:                        │
│   The correction must land where it will be loaded     │
│   and enforced AUTOMATICALLY in future sessions.       │
│   Memory alone is not enough — memory gets compacted.  │
└──────────────────────────────────────────────────────┘
```

**Protocol vs Reference:** This document explains *why* the loops exist and how they fail. The compact operational rules that agents enforce every session — the five loops plus the Self-Awareness Protocol — are in `protocol/learning-loops.md`, loaded at session start via Operate mode: every agent's Bootstrapping block invokes `Skill(second-brain)` with "operate" as its first action. The protocol is never copied into agent files or hubs. The contribution routing policy (auto vs prompt) is in `protocol/triage-policy.md`.

## The Compaction Problem

Claude Code uses a memory system (`memory/feedback_*.md` files indexed by `MEMORY.md`) to persist corrections across sessions. This is valuable but fragile. Memory files are project-scoped summaries — they're loaded into context at session start, but:

1. **Memory can be compacted.** When context gets long, memory entries can be summarized away. A nuanced behavioral correction becomes a one-line summary that loses the "why."
2. **Memory isn't scoped to agents.** A correction about how the financial agent frames spending findings lives in a global memory file. If a session loads the medical agent but not the financial agent, the correction is present in memory but not in the agent that needs it.
3. **Memory depends on context window co-loading.** For a memory correction to influence agent behavior, both the memory file AND the agent file must be loaded in the same context window simultaneously. This works when context is small. It fails when context is full.
4. **Memory files don't get audited for propagation.** There's no mechanism that checks whether a correction was actually incorporated into the agent it affects. It sits in memory indefinitely, potentially being the only barrier between the agent and repeating the same mistake.

The learning loops solve this by **dual-writing**: every correction goes to memory (the audit trail) AND to the place where it will actually be enforced (agent rules, knowledge files, or custodian checks). The agent's own files become the enforcement point. Memory becomes the history.

---

## Loop A: Behavior Corrections → Agent Rules

### What Triggers It

The user corrects Claude's behavior on a domain-specific task. Examples:
- "Don't flag my partner's travel spending as lifestyle creep — that category is funded on purpose"
- "Stop softening findings — lead with the number, not a hedge"
- "Never recommend an ISO exercise without re-verifying the live FMV — workbook snapshots go stale"
- "Don't anchor every cardiac symptom on AFib — maintain an explicit differential"

### What Goes Wrong Without It

The correction gets saved to `memory/feedback_budget-review.md`. Next session, the memory system loads the summary. But the financial agent's file — the thing that actually controls how budget reviews are framed — has no mention of this rule. If memory is compacted, or if the session loads the agent directly without the full memory index, the mistake recurs.

The user corrects the same behavior again. And again. Each time, it's saved to memory. Each time, it doesn't reach the agent. The system never improves — it just accumulates redundant memory entries.

### The Correct Flow

```
User corrects behavior
    │
    ├──→ [1] Save to memory/feedback_*.md
    │    (the audit trail — when was this learned, what was the context)
    │
    └──→ [2] Add the rule to the relevant agent file
         │   - Agent Rules section: behavioral rules
         │   - Workflow file: process-specific rules
         │   - Knowledge file: factual corrections
         │
         └──→ [3] Mark the feedback file as propagated
              Add `propagated_to: {target-file}` to its YAML frontmatter
```

### Where the Rule Goes

The destination depends on the nature of the correction:

| Correction Type | Destination | Example |
|----------------|-------------|---------|
| Agent behavioral rule | Agent's `## Rules` or Principles section | "Never recommend paying a bill before EOB reconciliation" → medical agent rule |
| Workflow process rule | The workflow `.md` file | "One item per bullet, target final density on first draft" → `5-15-workflow.md` |
| Factual correction | The knowledge file containing the wrong fact | "Dr. Alvarez replaced Dr. Chen as primary care physician" → `providers.md` |
| Cross-domain rule | Hub CLAUDE.md Ambient Guardrails | "Confirm before modifying any external service" → hub guardrail |

### The `propagated_to` Field

When a feedback file has been propagated, add this to its YAML frontmatter:

```yaml
---
name: 5-15-generation
description: Conciseness and scope rules for weekly 5-15 reports
type: feedback
propagated_to: Financial/financial-advisor.md
---
```

This field serves two purposes:
1. **Audit detection:** The custodian and audit mode can scan feedback files for missing `propagated_to:` fields to find unpropagated corrections.
2. **Traceability:** If the rule in the agent file is later questioned, you can trace it back to the original correction event.

Multiple propagation targets are valid — use a list:
```yaml
propagated_to:
  - Financial/financial-advisor.md
  - Financial/budget-targets.md
```

### What Good Looks Like

- The user corrects a behavior once
- The correction appears in the agent's Rules section within the same session
- The feedback file has `propagated_to:` set
- Future sessions load the agent and enforce the rule automatically — no memory dependency
- The custodian reports zero unpropagated feedback files

### What Bad Looks Like

- The user has corrected the same behavior three times across different sessions
- All three corrections are in separate memory files with no `propagated_to:`
- The agent file has no mention of the rule
- The custodian has never flagged this because nobody ran it

---

## Loop B: Tool/Workaround Discovery → Knowledge Files

### What Triggers It

A session discovers something operationally important that isn't documented anywhere:
- A tool limitation: "`WebFetch` fails for sites behind a private CA — use `mcp__obsidian-mcp-tools__fetch` instead"
- An API quirk: "The insurance portal logs you out after 10 minutes idle — export within the window or the session drops"
- A deployment gotcha: "Export the FSA statement before Dec 31 — the portal purges prior-year data in January"
- A data-quality quirk: "The auto-loan connector never refreshes the balance — trust the statement payoff, not the aggregator number"
- An integration gap: "MyChart has no live MCP — manual export only until the Health Record MCP lands"

### What Goes Wrong Without It

The discovery lives only in memory. Or worse, only in the conversation transcript. The next session either doesn't know about it at all, or finds a one-line memory summary that lacks enough context to be useful. The engineer (or Claude) hits the same issue, wastes time rediscovering the same workaround, and the cycle repeats.

The particularly insidious version: a workaround gets saved to memory with full context. Memory loads at session start. For weeks, everything works. Then the memory file gets compacted down to a summary. The summary loses the critical detail (which port, which tool, which exact command). The workaround is now known to exist but can't be applied. It's worse than not knowing — it's a false sense of coverage.

### The Correct Flow

```
Session discovers workaround/quirk/gap
    │
    ├──→ [1] Determine scope: single-agent, cross-domain, or upstream gap?
    │
    ├──→ [Single agent] Update agent's Domain Context or knowledge file
    │    Add `[learned: YYYY-MM-DD]` annotation
    │    If it has a shelf life, add `[review-by: YYYY-MM-DD]`
    │
    ├──→ [Cross-domain] Update hub CLAUDE.md Shared Context section
    │    Or create/update a shared knowledge file at the hub level
    │
    └──→ [Upstream gap] Note in the agent and also flag for skill/MCP improvement
         "This workaround exists because {tool} doesn't support {feature}.
          Upstream fix: {what a better connector would look like}."
```

### Where the Discovery Goes

| Discovery Scope | Destination | Example |
|----------------|-------------|---------|
| Single-agent operational knowledge | Agent's `## Domain Context` or a knowledge file | "The Kaiser member portal needs the member ID, not the MRN, to pull claims" → medical agent's troubleshooting notes |
| Cross-domain tool limitation | Hub `## Shared Context` | "WebFetch fails for private CA — use obsidian-mcp-tools fetch" → hub shared context |
| Integration gap worth fixing | Both: local knowledge file + upstream note | "MyChart has no live MCP — manual export only until a Health Record MCP lands. Upstream: build a MyChart export connector." |
| Time-sensitive status | Knowledge file with `decay: fast` | "FSA balance $3,400, use-it-or-lose-it Dec 31" → `benefits.md` with `[review-by: 2026-12-01]` |

### Annotation Requirements

Every discovered fact must carry provenance:
- **`[learned: YYYY-MM-DD]`** — when the fact was first written down. Never backdate this. If you're writing it today, the learned date is today, even if the underlying fact is older.
- **`[review-by: YYYY-MM-DD]`** — when the fact should be re-verified. Required for fast-decay facts. Recommended for anything with a known expiration.

Do NOT use `[learned:]` to annotate facts retroactively during bulk annotation passes. If you're adding annotations to existing content that predates the Second Brain, use today's date — it represents when the fact entered the system's tracking, not when it was originally true.

Facts that record a **decision** — a fork someone actually chose, not something observed or inferred — additionally carry **`[decided: <who>, YYYY-MM-DD]`**, where `<who>` is a human name or an agent id. This is epistemic provenance: years later, "we chose X" must be distinguishable from "the portal showed X." Reserve it for genuine decisions (an agent deriving a fact from a document is inferring, not deciding), and treat agent-attributed decisions as ratification candidates — the audit surfaces them for a human to confirm. Full grammar and worked examples: `protocol/knowledge-schema.md`.

### What Good Looks Like

- A workaround is discovered, documented in the agent's knowledge file within the same session, annotated with `[learned:]` and `[review-by:]` where appropriate
- Future sessions load the knowledge file and see the workaround without needing memory
- If the workaround becomes obsolete (the upstream tool gets fixed), the `[review-by:]` date triggers a review and the entry gets marked `[superseded:]`

### What Bad Looks Like

- The workaround lives in a memory file or a Slack thread
- An engineer hits the same issue 3 months later, spends an hour debugging, then finds the Slack thread
- The agent has no record of the workaround — it can't help

---

## Loop C: Quality → Custodian Self-Improvement

### What Triggers It

The user manually catches a vault issue that the automated health check (custodian) should have caught but didn't:
- A wrong cross-link between knowledge files
- A stakeholder whose title changed but the people index wasn't updated
- A knowledge file that was clearly stale but wasn't flagged because it had no `review_by:` date
- A structural problem (file in the wrong folder, orphaned knowledge file, agent referencing a deleted path)
- A factual inconsistency between two knowledge files that the conflict check didn't detect

### What Goes Wrong Without It

The user fixes the issue. Nothing else happens. The custodian's checklist is the same static list it was when first created. Next month, the same class of issue appears — a different stakeholder's title changes, a different knowledge file goes stale, a different cross-link breaks — and the custodian still doesn't catch it. The user manually fixes it again. The custodian never learns.

This is the classic problem with automated checks: they only catch what they were designed to catch. Without Loop C, the custodian never gets smarter. With Loop C, every manual correction teaches the custodian a new check class.

### The Correct Flow

```
User manually catches vault issue
    │
    ├──→ [1] Fix the issue in the vault
    │
    └──→ [2] Identify the CLASS of issue (not just the specific instance)
         │   "The custodian doesn't check for title changes vs. people index"
         │   "The custodian doesn't check for review_by on decay:fast files"
         │
         └──→ [3] Add the check to custodian-workflow.md
              Under the appropriate step, add the new check
              Note: "Added [date] based on manual catch of [specific issue]"
```

### What Gets Added to the Custodian

The custodian workflow is organized in steps (freshness, propagation, size, conflicts). When adding a new check, place it under the right step:

| Issue Class | Custodian Step | Check to Add |
|-------------|---------------|--------------|
| Stale content not flagged | Step 3 (Freshness) | Check `decay: fast` files for missing `review_by:` dates |
| Stakeholder title drift | Step 6 (Conflicts) | Compare domain stakeholder files against people index titles |
| Orphaned knowledge file | Step 5 (Size/Structure) | Scan for `.md` files not referenced by any agent routing rule |
| Missing cross-link | Step 5 (Size/Structure) | When a knowledge file mentions a sibling file's topic, check for cross-link |
| Feedback not propagated | Step 4 (Propagation) | Already covered — but if a specific pattern of missed propagation recurs, refine the detection |

### Evolutionary Growth

The custodian starts with a basic set of checks (the ones defined during hub creation). Over time, Loop C grows it:

```
Month 1:  5 checks (initial set from template)
Month 2:  7 checks (user caught a stale title, added title-drift check; caught an orphan, added orphan check)
Month 3:  9 checks (user caught a missed cross-link pattern; caught a fast-decay file without review_by)
Month 6: 14 checks (the custodian now catches most common issues automatically)
```

Each check addition should include a comment noting the origin:
```markdown
## Step 6: Cross-Domain Stakeholder Conflicts
...
- Compare domain stakeholder titles against People Index canonical titles
  (Added 2026-04-15: caught Dr. Patel listed as "Pediatrician" in Medical
   but "Family Doctor" in People Index — class: title drift)
```

### What Good Looks Like

- The user catches an issue manually maybe once or twice
- After the second catch, the custodian has a check for that class
- The third instance of the same class is caught automatically
- Over months, the custodian's checklist grows from 5 to 15+ checks, all grounded in real issues

### What Bad Looks Like

- The user catches the same class of issue manually every month
- The custodian checklist never grows
- The user starts ignoring the custodian because "it doesn't catch anything useful"

### Data-Driven Evolution

Loop C is stronger when backed by telemetry rather than relying solely on user-reported catches. Each custodian run appends metrics to `_reports/loop-health.json`:

```json
{
  "date": "YYYY-MM-DD",
  "corrections_propagated": 5,
  "corrections_pending": 1,
  "discoveries_written": 3,
  "contradictions_detected": 0,
  "custodian_checks_total": 9,
  "custodian_checks_added_this_run": 1
}
```

Over time, this data reveals patterns:
- **Stagnant check count** (no growth in 30+ days while sessions are active) → surface a prompt asking if there are manual catches the custodian should learn
- **High pending-to-propagated ratio** → Loop A isn't keeping up; consider switching to `auto_contribute: true`
- **Contribution approval/rejection patterns** → when users consistently approve a category that the triage policy routes to prompt, that category may be ready for auto-eligible reclassification

The operational protocol (`protocol/learning-loops.md`) and triage policy (`protocol/triage-policy.md`) reference this telemetry for data-driven policy evolution.

---

## Loop D: Contradiction Velocity → Auto-Flag

### What Triggers It

A session discovers or writes a fact that directly contradicts an existing entry in a knowledge file:
- "Dr. Alvarez is the primary care physician" but `providers.md` says "Dr. Chen is the primary care physician"
- "The 2026 Roth IRA contribution limit is $7,000" but `limits.md` says "$6,500"
- "The pediatrician is in-network" but `benefits.md` says "out-of-network"

### What Goes Wrong Without It

Without contradiction detection, the new fact silently overwrites or coexists with the old one. If the new fact is wrong, the knowledge base now contains an error that was validated by no one. If the old fact was wrong, the contradiction is a correction opportunity that was missed. Either way, the system has no mechanism for surfacing conflicting claims — it just stores whatever was written most recently.

The particularly dangerous case: two different sessions write contradicting facts about the same topic on different days. Both get written to knowledge files. Neither knows the other exists. A future reader sees whichever one they happen to load first and treats it as authoritative.

### The Correct Flow

```
Session writes fact that contradicts existing knowledge
    │
    ├──→ [1] Tag existing entry with [disputed: YYYY-MM-DD]
    │
    ├──→ [2] Add both claims (old + new) with sources
    │    to a ## Disputed Facts section in the knowledge file
    │
    └──→ [3] Surface the contradiction to the user immediately
         (ALWAYS prompt, regardless of auto_contribute setting)
         "Found contradiction: {old claim} vs {new claim}.
          Which is correct? Or should both be preserved as disputed?"
```

### Velocity Escalation

A single contradiction is a normal correction. Repeated contradictions of the same fact are a systemic signal:

- **1 contradiction:** Surface to user, tag `[disputed:]`, resolve in-session if possible
- **2+ contradictions of the same fact in 30 days:** Escalate — surface as a Critical finding in the next custodian run. This means the knowledge base has a fact that multiple sources disagree on, and it needs authoritative resolution (find the source of truth, not just pick the most recent claim).

Track contradiction frequency via `[disputed:]` annotations — the custodian scans for these and counts recurrences.

### What Good Looks Like

- A session discovers a contradicting fact and immediately flags it
- The user resolves it in-session (one claim is confirmed, the other is marked `[superseded:]`)
- The contradiction count in `_reports/loop-health.json` stays low because contradictions are resolved when discovered

### What Bad Looks Like

- Two knowledge files contain contradicting facts about the same topic
- Neither is tagged `[disputed:]` — nobody knows the conflict exists
- A stakeholder gets different answers depending on which knowledge file the agent loads first
- The contradiction persists for months because no mechanism surfaces it

---


## Loop E: Process Retrospection → Agent Definitions

### What Triggers It

Loops A-D are reactive — they fire when the user corrects something or a session stumbles onto a fact. Loop E fires **proactively at every task-completion gate**, whether or not anything went visibly wrong. The agent asks four questions about its own instructions:

1. Did my instructions produce a good answer, or did I have to work around them?
2. Did the user correct my approach, tone, or framing — not just facts?
3. Did I discover a judgment frame, tradeoff, or heuristic that isn't in my agent file?
4. Did I follow a rule that felt wrong, or skip a step that was prescribed?

Examples:
- The agent's lifestyle-spending thresholds flagged a category, but the user explained the spend was a deliberate, valued exception — the *threshold* is right but the *frame* is missing a carve-out
- The agent's output template forced a tabular breakdown onto a question that needed two paragraphs — the template is a procedure where a principle ("structure serves the question") belongs
- A prescribed data-pull step wasted five minutes on a strategy question that didn't need live data — the rule needs a "pull only when the answer depends on it" qualifier
- The agent answered well, but only because it improvised a heuristic ("verify the live FMV before sizing any exercise") that exists nowhere in its file — capture it before it evaporates

### What Goes Wrong Without It

Without Loop E, agent files only improve when the user notices and corrects a failure (Loop A). But most instruction-level problems are invisible to the user — they show up as the agent quietly working around its own rules, or as good judgment that lives only in the transcript. The agent file slowly diverges from how the agent actually (successfully) operates. Worse, dead rules accumulate: instructions that get routinely worked around stay in the file, costing context and credibility, because nothing ever evicts them.

### The Correct Flow

```
Task completes → agent runs the four questions
    │
    ├──→ [Nothing fired] Move on. (Most tasks.)
    │
    └──→ [Something fired]
         │
         ├──→ [1] Classify: knowledge gap → Loop B; stale data → Loop B + decay fix;
         │        wrong judgment → Loop E; tool failure → Loop B + upstream note
         │
         ├──→ [2] Draft the revision to the agent definition
         │        - Prefer a principle over a procedure
         │        - If the lesson came from a real failure, embed it as a worked example
         │        - If an existing rule caused a workaround: propose revising or REMOVING it
         │
         └──→ [3] ALWAYS prompt the user (regardless of auto_contribute)
              "Loop E: this session suggests a change to {agent}: {proposed revision}. Apply?"
```

### The Eviction Discipline

The skill-library insight (Voyager pattern): a library compounds only if entries earn their place. A rule the agent had to work around is a bug in the rule — revise it or remove it. Do not accumulate rules monotonically. When proposing a Loop E revision, check whether an existing rule should *shrink* as part of the same change. The agent file's authority depends on every rule in it being live.

### Worked Examples Are the Payload

An abstract rule ("verify data freshness before acting") gets rationalized away under pressure. The same rule with its origin story attached ("Worked example: a weeks-old valuation snapshot turned a modeled zero-tax equity exercise into a five-figure surprise — pull the live number before sizing any order") survives, because future sessions can see what ignoring it costs. When Loop E captures a judgment lesson, capture the example with it.

### What Good Looks Like

- The agent file converges toward how the agent actually operates well — principles tighten, dead rules disappear
- Most Loop E proposals are small: a qualifier on an existing principle, a worked example added, a procedure demoted to a principle
- The user sees a Loop E proposal every handful of sessions, not every session (every session = the bar is too low; never = the reflex is dead)
- `_reports/loop-health.json` shows `process_revisions_proposed` ticking up slowly over months

### What Bad Looks Like

- The agent file hasn't changed in months while the agent visibly improvises around it
- Rules accumulate but never get removed; the file grows past its size budget with instructions nobody trusts
- Loop E proposals are vague ("be more careful with data") instead of specific revisions with examples

---

## Infrastructure Required

For the loops to work, certain infrastructure must exist. This is what `/second-brain create` sets up and `/second-brain improve` checks for.

### Loop A Infrastructure

| Component | Purpose | Created By |
|-----------|---------|-----------|
| `memory/feedback_*.md` files | Audit trail for corrections | User's Claude Code memory system (automatic) |
| `memory/MEMORY.md` | Index of feedback files | User's Claude Code memory system (automatic) |
| `propagated_to:` frontmatter field | Tracks whether correction reached its target | Loop A itself (added during propagation) |
| Agent `## Rules` section | Enforcement point for behavioral rules | `/second-brain create` (template includes Rules section) |
| Custodian Step 4 (Propagation Check) | Detects unpropagated corrections | `/second-brain create` or `/second-brain add-workflow` (custodian pattern) |

### Loop B Infrastructure

| Component | Purpose | Created By |
|-----------|---------|-----------|
| Agent `## Domain Context` section | Home for single-agent workarounds | `/second-brain create` (template includes Domain Context) |
| Knowledge files with frontmatter | Home for domain-specific discoveries | `/second-brain create` (starter files) |
| `[learned:]` / `[review-by:]` annotations | Provenance and staleness tracking | Protocol annotation rules (`protocol/knowledge-schema.md`, loaded via Operate mode) |
| `[decided: <who>, YYYY-MM-DD]` annotations | Epistemic provenance for decisions — human name or agent id; agent decisions are ratification candidates | Loop B itself, per `protocol/knowledge-schema.md` |
| Hub `## Shared Context` | Home for cross-domain discoveries | `/second-brain create` (hub template) |
| `.staleness-manifest.json` | Mechanical drift detection for sourced files | `/second-brain audit` (seeded on first run) |

### Loop C Infrastructure

| Component | Purpose | Created By |
|-----------|---------|-----------|
| `custodian-workflow.md` | The checklist that grows | `/second-brain add-workflow` (custodian pattern) or manual creation |
| `_reports/custodian-*.md` | Output reports | Custodian itself (each run writes a report) |
| `_reports/loop-health.json` | Quantitative loop telemetry (corrections, discoveries, contradictions, check count) | Custodian and audit (append per run) |
| Hub Ambient Guardrails staleness nudge | Reminds user if custodian hasn't run | `/second-brain create` (hub template) |
| Weekly report Step 7.5 | Automatic custodian integration | `/second-brain add-workflow` (weekly report pattern) |

### Loop D Infrastructure

| Component | Purpose | Created By |
|-----------|---------|-----------|
| `[disputed: YYYY-MM-DD]` annotations | Tags contradicted facts in knowledge files | Loop D itself (added when contradiction detected) |
| `## Disputed Facts` section | Collects both claims with sources in knowledge file | Loop D itself (created on first contradiction) |
| `_reports/loop-health.json` contradictions counter | Tracks contradiction frequency for velocity detection | Custodian (appends per run) |
| Agent frontmatter `auto_contribute:` | Controls write-directly vs prompt-user behavior — the gate rule ships in the protocol and resolves this setting at bootstrap | `/second-brain create` (agent template frontmatter) |

### Loop E Infrastructure

| Component | Purpose | Created By |
|-----------|---------|-----------|
| Task-completion gate — the four questions | Fires the retrospection reflex | Protocol (`protocol/learning-loops.md`), loaded every session via Operate mode |
| Agent `## Bootstrapping` block | Cross-session mandate that the review happens — the gate arrives with the protocol, every session | `/second-brain create` or `adopt` (agent template) |
| `process_revisions_proposed` counter in `_reports/loop-health.json` | Telemetry — detects a dead reflex | Custodian (appends per run) |
| Worked-example convention in Guiding Principles | Makes captured judgment durable | Agent template |

### Self-Awareness Infrastructure

| Component | Purpose | Created By |
|-----------|---------|-----------|
| Agent `## Bootstrapping — Required, Every Session` block | First action every session: `Skill(second-brain)` with "operate" loads the protocol; fail-visible read-only contract if the skill is missing | `/second-brain create` (agent template) |
| Self-Awareness Protocol (in `protocol/learning-loops.md`) | Two-phase discipline: continuous contribution reflex + task-completion gate (incl. the four Loop E questions) — loaded via Operate mode, never written into agent files | Skill (bundled) |
| Agent frontmatter `auto_contribute:` | `true\|false` — controls contribution behavior per agent; Operate mode resolves it from the invoking agent's own frontmatter (subagents resolve their own, never inherit) | `/second-brain create` (agent template) |
| `protocol/learning-loops.md` | The five loops + Self-Awareness Protocol — the operational rules every session runs on | Skill (bundled) |
| `protocol/triage-policy.md` | Contribution routing: auto-eligible vs always-prompt | Skill (bundled) |
| `protocol/knowledge-schema.md` | Canonical frontmatter schema and annotation grammar for knowledge files | Skill (bundled) |

Earlier versions had a third phase: a session-start warm-up scan that inventoried knowledge-file freshness before any work began. It was removed deliberately — a per-session inventory pays a hot-path context cost on every task while catching staleness only by coincidence. Staleness detection is a deliberate audit operation: freshness inventory now belongs to the custodian and `/second-brain audit`, not to the per-session discipline.

---

## How Each Skill Mode Uses These Loops

### `/second-brain create`

**What it sets up:**
- Agent template includes the `## Bootstrapping — Required, Every Session` block — the session's first action loads the protocol (five loops, Self-Awareness Protocol, contribution gate, schema) via `Skill(second-brain)` with "operate"; the protocol itself is never written into the agent file
- Agent template declares `auto_contribute:` in frontmatter — the Contribution Gate rule ships in the protocol and reads this setting at bootstrap
- Hub template includes the `## Operating Protocol — Loaded, Not Restated` pointer section — loop definitions live only in the skill, never copied into hubs
- Hub template includes `## Contribution Settings` as a convenience registry (each agent's frontmatter is authoritative; `auto_contribute: false` is the default)
- Hub template includes custodian staleness nudge in Ambient Guardrails
- If the user selects a weekly report workflow, offers to add Step 7.5 (custodian integration)

**What it does NOT set up:**
- The custodian itself — this is a separate workflow, offered as a follow-up
- Memory infrastructure — this is managed by Claude Code, not the skill
- The `propagated_to:` field — this is added organically when Loop A fires
- `_reports/loop-health.json` — seeded on first custodian run

### `/second-brain audit`

**What it checks (Step 3b: Learning Loop Health):**
- **Loop A health:** Scans `memory/feedback_*.md` for domain-specific corrections without `propagated_to:`. Flags as "pending propagation" with severity Important.
- **Loop B health:** Scans agent Domain Context for content that reads like workarounds (tool limitations, API quirks) rather than stable architecture. Flags as Minor to encourage migration to knowledge files with proper annotations.
- **Loop C health:** Checks if `custodian-workflow.md` exists. Checks when it last ran. If >14 days → Minor. If >30 days → Important. If never → Minor. Reviews `_reports/loop-health.json` for check-count stagnation.
- **Loop D health:** Scans knowledge files for `[disputed:]` annotations older than 14 days without resolution. Flags as Important — unresolved contradictions erode trust.
- **Loop E health:** Compares each agent file's git history against session activity. An agent actively used for 60+ days with zero definition changes and zero recorded reviewed-no-change notes → Minor ("process retrospection may not be firing"). Rules sections that exceed size budgets → Minor ("check for dead rules — eviction discipline").

### `/second-brain improve`

**What it proposes:**
- **Low effort:** Add the `## Bootstrapping` block to agents missing it and declare `auto_contribute:` in their frontmatter — never paste the Self-Awareness Protocol into the agent file; it loads via Operate mode. Ensure `Skill` is in the tools list (the bootstrap depends on it). Safe to auto-apply. For hubs upgrading from a pre-2.0 protocol copy, follow `references/migration.md`.
- **Medium effort:** Review unpropagated feedback files and suggest propagation targets. Requires user judgment on where each correction should go.
- **Medium effort:** Resolve outstanding `[disputed:]` entries — present both claims and ask user to adjudicate.
- **Medium effort:** Upgrade from `auto_contribute: false` to `true` for agents with clean audit history (low contradiction rate, no recent false contributions).
- **High effort:** Set up the custodian workflow if it doesn't exist. Redirects to `/second-brain add-workflow`.

### `/second-brain add-workflow` (Custodian Health Pulse pattern)

**What it generates:**
- A `custodian-workflow.md` at the hub root with the standard check steps
- An initial check set (freshness, review_by, feedback propagation, size budgets, stakeholder conflicts)
- Integration guidance for weekly report workflow (Step 7.5 pattern)
- The staleness nudge rule for the hub's Ambient Guardrails

---

## Measuring Loop Health

The audit produces a quantitative assessment of loop health as part of its overall score.

| Metric | Green | Yellow | Red |
|--------|-------|--------|-----|
| Loop A: Feedback propagation rate | 100% of domain-specific corrections propagated | 70-99% propagated | <70% propagated |
| Loop B: Workaround documentation | All workarounds in knowledge files with `[learned:]` | Some in memory only | Workarounds undocumented |
| Loop C: Custodian growth | Custodian checklist has grown since initial creation; `loop-health.json` tracks metrics | Checklist unchanged but custodian runs regularly | Custodian doesn't exist or hasn't run in 30+ days |
| Loop D: Contradiction resolution | No `[disputed:]` annotations older than 14 days | 1-2 unresolved disputes | 3+ unresolved disputes or contradictions never flagged |
| Loop E: Process retrospection | Agent files revised within last 60 days of active use, or explicitly reviewed-no-change | Proposals happening but vague/unapplied | No agent-definition change in 90+ days of active use |

The maturity model ties loop health to levels:
- **L3** requires basic loop infrastructure (unconditional Bootstrapping block in every agent with `Skill` in the tools list, `auto_contribute` declared in the agent's own frontmatter, hub has the Operating Protocol pointer section)
- **L4** requires loops actively working (`auto_contribute: true`, propagation rate Green, custodian running regularly, contradictions resolved within 14 days)
- **L5** requires loops compounding (custodian checklist has grown, upstream contributions from Loop B discoveries, triage policy has evolved via Loop C data)

---

## Common Failure Modes

### "We save corrections to memory, isn't that enough?"

No. Memory is the audit trail, not the enforcement point. Memory gets compacted. Memory isn't scoped to agents. Memory depends on context window co-loading. The correction must also live in the agent file.

### "The agent file is getting too long with all these rules"

Rules should be concise — one line per rule is the target. If a behavioral correction requires multiple paragraphs of context, the rule in the agent should be one line, and the full context should be in a knowledge file that the rule references: "For 5-15 scope rules, see `5-15-workflow.md`."

### "Loop C feels artificial — we don't catch issues that often"

If you're not catching issues, either: (a) the custodian is comprehensive enough (good), or (b) you're not running the custodian frequently enough to notice when it misses things (bad). Run it weekly via the report workflow. Issues will surface.

### "We have 20 feedback files and none are propagated"

This is backlog, not failure. Run `/second-brain audit` — it will list all unpropagated files with suggested targets. Then work through them: some will be genuinely domain-specific (propagate to agent rules), some will be cross-domain (propagate to hub rules), some will be obsolete (mark as superseded). The goal isn't zero backlog — it's that new corrections get propagated in the same session they occur.

### "The custodian keeps flagging things that aren't real issues"

Refine the check. A check that produces false positives is worse than no check — it trains you to ignore the custodian. When a check produces a false positive, don't just dismiss it. Ask: can the check be more precise? If yes, update it. If no, remove it. The custodian's value is in signal quality, not quantity.
