# Workflow Pattern Catalog

Repeatable workflows transform domain agents from passive Q&A assistants into active operational tools. Each pattern here has been proven in production.

## Available Patterns

### 1. Status Report (5-15 Pattern)

**What:** Generate periodic status reports from multiple data sources, organized by lines of effort or categories.

**Audience:** Leadership, customers, program stakeholders

**Architecture:**
- Define Lines of Effort (LOE) relevant to the domain (e.g., Software Development, External Dependencies, Compliance, Deliverables)
- For each LOE, track: Accomplishments (past tense), Open Work (present/future), Blockers
- Trawl multiple sources in parallel for raw data
- Synthesize, deduplicate, and organize by LOE
- Apply content filtering (exclude internal-only items, scope to relevant domain)
- Surface for human review before distribution

**Key features:**
- Parallel source trawling (Slack channels, Jira boards, Confluence pages, vault notes)
- Content filtering rules (INTERNAL exclusions, scope boundaries)
- Human review gate — never auto-publish
- Prior-report carry-forward (check previous report for open work and blockers)
- Cron-automatable (generate draft on schedule, review manually)

**When to use:** Any program or team that produces recurring status updates for stakeholders.

---

### 2. Collector Pipeline

**What:** Gather data from many sources using independent collector agents, each with a standardized output contract.

**Audience:** Self (retrospection), team (evidence gathering)

**Architecture:**
- **Orchestrator** dispatches collector agents in waves
- **Collectors** are standalone markdown files, each responsible for one data source
- Standard input: `week`, `start_date`, `end_date`, `person`, `batch_mode`
- Standard output: JSON with `source`, `status` (green/yellow/red), `data`, `errors[]`
- **Wave dispatch:** Wave 1 = no dependencies (parallel). Wave 2 = depends on Wave 1 data (also parallel among themselves)
- **Graceful degradation:** Failed collectors return status=red with empty data. Report generates with whatever succeeded.

**Key features:**
- Each collector is independently testable and replaceable
- Adding a new source = adding one collector file + registering it in the orchestrator
- Health status per source → visible in output metadata
- `--fast` flag to skip slow/optional collectors
- `--batch` flag for non-interactive cron execution

**When to use:** Any report that aggregates data from 4+ sources and benefits from parallel collection and graceful degradation.

#### Extension: Cross-System Consistency Checks

When multiple collectors return data about overlapping entities, the orchestrator can run **consistency checks** across their outputs. This catches drift between systems that individually look healthy but disagree with each other.

**Consistency dimensions to check:**

| Dimension | Source A | Source B | Mismatch means |
|---|---|---|---|
| Ticket existence | Status report references ticket | Jira board | Dead link — ticket deleted, moved, or mistyped |
| Person-role agreement | Domain `stakeholders.md` | People index / org chart | Role changed and one file wasn't updated |
| Schedule alignment | Knowledge file milestone dates | Jira epic target dates | Schedule slipped in one system but not the other |
| Document currency | Knowledge file `sources:` pointer | Actual document (Confluence version, file mtime) | Source was updated but knowledge file wasn't (overlaps with staleness manifest) |
| Status coherence | Status report "blocked" items | Jira ticket status field | Report says blocked but ticket says In Progress (or vice versa) |

**Implementation pattern:** After all collectors return, run consistency checks as a post-collection step. Each check compares fields across two collector outputs. Report mismatches as warnings — they're almost always data hygiene issues, not errors. Let the user decide which to fix.

**When to add this:** Once a collector pipeline has 4+ sources covering overlapping domains. Don't over-engineer a 2-source pipeline with consistency checks it doesn't need.

---

### 3. RFC / Document Authoring

**What:** Guide structured document creation using templates, domain knowledge, and stakeholder awareness.

**Audience:** Technical reviewers, decision makers

**Architecture:**
- Template with standard sections (Problem Statement, Proposed Solution, Alternatives Considered, Migration Plan, Open Questions)
- Pre-populate with known context from knowledge files
- Route to relevant stakeholders for review based on domain
- Track feedback and iterate

**Key features:**
- Template-driven — consistent structure across documents
- Stakeholder-aware — knows who should review what
- Knowledge-enriched — pulls from agent's semantic knowledge to pre-fill context
- Review routing — suggests reviewers based on domain expertise in stakeholders.md

**When to use:** Any team that produces technical proposals, design documents, or decision records.

---

### 4. Compliance Scanning

**What:** Execute security/compliance scanning procedures and update tracking artifacts.

**Audience:** Security reviewers, compliance owners

**Architecture:**
- Scanning runbook with step-by-step procedures
- Action-item register updates from scan results
- Evidence pack generation
- Feedback response workflow (parse reviewer comments, draft responses)

**Key features:**
- Runbook-driven — repeatable procedures that don't drift
- Artifact generation — produces documents in required formats
- Risk assessment — conservative by default for security/compliance
- Audit trail — tracks what was scanned, when, and what was found

**When to use:** Any recurring compliance or audit process (SOC 2, HIPAA, PCI, internal policy).

---

### 5. Schedule Assessment

**What:** Evaluate readiness against a deadline by checking critical path items, dependencies, and blockers.

**Audience:** Program managers, leadership

**Architecture:**
- Readiness checklist with critical milestones
- Dependency tracking (what blocks what)
- Status assessment per milestone (on track / at risk / blocked)
- Critical path identification

**Key features:**
- Deadline-driven — always oriented around a target date
- Dependency-aware — flags when upstream items are late
- Risk-colored — green/yellow/red per milestone
- Actionable — each at-risk item has a suggested next step

**When to use:** Programs with hard deadlines (ship dates, reviews, demos) and complex dependency chains.

---

### 6. Sprint Orchestration

**What:** Manage a time-boxed sprint toward a specific deliverable (demo, release, review).

**Audience:** Sprint team

**Architecture:**
- North star deliverable (the demo path, the release criteria)
- Work area routing (which skills/tools handle which areas)
- Session start protocol (load state, check health, present delta, ask what to work on)
- Scope discipline (ruthlessly cut anything not on the critical path)

**Key features:**
- Demo-path focused — every decision measured against "does this help the demo?"
- Skill delegation — routes to specialized skills for specific work areas
- Session continuity — start protocol rebuilds context quickly
- Hard deadline awareness — countdown visible, scope decisions accordingly

**When to use:** Any team sprinting toward a specific event (demo, conference, review, ship date).

### 7. Custodian Health Pulse

**What:** Lightweight recurring vault health check. Faster than a full audit — designed to run weekly as part of a status report workflow.

**Audience:** Self (vault maintenance)

**Architecture:**
- Establish baseline: find last run date, compute days since
- Git activity scan: identify which domains had changes since last run
- Per-active-domain freshness check: `last_updated` vs. decay rate, overdue `review_by` dates
- Feedback propagation check: scan memory feedback files for `propagated_to:` — flag any domain-specific corrections not yet applied to agent rules (Loop A backlog)
- **Size budget enforcement**: count lines in every agent file, knowledge file, and hub CLAUDE.md. Compare against budgets (agent: 300, knowledge: 200, hub: 200). Flag at 1.5x as warning, 2x as action-required. For action-required files, suggest a specific split: which content to extract and where to put it.
- Stakeholder conflict check: quick diff of domain stakeholder files vs. people index (if one exists)
- Output: `_reports/custodian-YYYY-MM-DD.md` + one-line summary for embedding

**Key features:**
- Fast — only checks active domains, not the entire vault
- Runs as a step inside the weekly report workflow (Step 7.5 pattern)
- Also callable standalone as an on-demand health check
- Self-improving via Loop C: when user catches an issue the custodian missed, the check gets added
- Staleness nudge: hub CLAUDE.md surfaces a reminder if no custodian report in 14+ days
- **Active size enforcement**: catches bloat before it becomes a context-window problem — flags files over budget with specific split recommendations rather than just noting "file is big"

**When to use:** Any Second Brain with 3+ agents and a weekly report workflow. Add it as Step 7.5 in the report workflow so health checking happens automatically without a separate invocation.

---

### 8. Golden-Question Eval

**Problem:** No objective signal whether the knowledge base is compounding or decaying. Sessions feel fine until a stale fact produces a confidently wrong answer.

**Pattern:** Per-domain `golden-questions.md` (scaffold: `assets/golden-questions-template.md`) — 10-20 questions where a wrong answer matters, sourced from real sessions plus adversarial and must-pass ground-truth cases.

**Cadence:** Quarterly, or after major knowledge restructuring.

**Flow:**
1. Fresh session (the agent must not see expected answers): load the agent, ask each question
2. Compare against expected key facts; optionally score with an isolated judge session against the rubric
3. Each Fail → classify (knowledge gap / stale data / wrong judgment / tool failure) → route per the loops (B fixes the file, E fixes the agent)
4. Record run in the file's run log with propagation notes; failed questions stay in the set as regression guards
5. Headline metric over time: corrections-per-session and eval pass rate. Pass rate flat-or-rising + corrections falling = compounding.

### 9. Correction Mining

**Problem:** Corrections happen in sessions that never run a retrospection pass — they sit in transcripts and harness memory, unpropagated. (This is Loop A's backlog accumulating invisibly.)

**Pattern:** A monthly meta-session that mines recent activity for unpropagated corrections.

**Flow:**
1. Scan harness memory (`memory/feedback_*.md` or equivalent) for entries lacking `propagated_to:`
2. Review recent session summaries/transcripts where available: (a) facts the user corrected, (b) approaches the user redirected, (c) information an agent lacked that it should have had
3. For each finding: propose the propagation target (agent rule, principle + worked example, knowledge file, custodian check)
4. Apply per `auto_contribute` / triage policy; mark memories `propagated_to:`
5. Append counts to `_reports/loop-health.json`

**Integration:** fold into the custodian as a monthly step, or run standalone. The audit's Loop A check is the safety net; this pattern is the active sweep.

### 10. Session-End Wrap

**Problem:** The task-completion gate is advisory — sessions end without it firing, and nothing else can diff the *conversation* against the *files* while the conversation still exists (audits and custodians only ever see files). The owner ends up manually asking "did everything from our session get persisted?"

**Pattern:** `/second-brain wrap` (`references/mode-wrap.md`) — a transcript pipeline: `scripts/extract_session.py` digests the session transcript, a Sonnet subagent harvests candidates and diffs each against its target knowledge file, and the invoking conversation judges the result — three-bucket ledger (**Captured / Missing / Ambiguous**), gaps persisted per `auto_contribute`, the Loop E gate, `run_type: "session-end"` telemetry appended to `_reports/loop-health.json`, `.session-gate` touched.

**Cadence:** End of every substantive working session — invoked *in* the session that did the work (the extractor exits non-zero on a fresh session rather than let wrap fabricate a ledger).

**Key features:**
- Transcript in, judgment inline — the digest survives context compaction where recall doesn't; only the mechanical harvest/diff is delegated, and deciding what persists stays in the invoking conversation
- Verification net, not write path — the continuous contribution reflex stays primary
- `wrap_missing` trend is the health signal for the contribution reflex itself
- `.session-gate` marker is the forward contract for hook enforcement (`enforcement-hooks.md`) if telemetry shows the ritual being skipped
- Two-keystroke alias shim (`/wrap`) offered on first run

**When to use:** Any hub whose owner has ever ended a session unsure whether its discoveries were captured.

## Creating a Custom Workflow

If none of these patterns fit exactly, use `/second-brain add-workflow` to:

1. Select the closest pattern as a starting point
2. Customize the sources, output format, audience, and scheduling
3. Generate the workflow file and wire it into the agent's routing

Custom workflows can combine elements from multiple patterns (e.g., a Status Report that uses the Collector Pipeline architecture).
