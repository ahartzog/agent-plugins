# The Second Brain Operating Model

A framework for AI-assisted domain knowledge management that keeps getting smarter.

## The Problem

Engineers accumulate enormous domain knowledge across Claude Code sessions. Without persistence, every session starts from zero. You re-explain your program's architecture, re-point Claude at the right repos, re-describe your team's conventions — every single time.

Meanwhile, tribal knowledge lives scattered across chat threads, buried wiki pages, undiscoverable docs, and people's heads. When someone leaves or a new engineer onboards, that knowledge evaporates.

## The Solution: Domain Agents with Living Knowledge

A **domain agent** is a persistent AI persona scoped to a specific area of work. It knows:
- What questions to answer and what to delegate elsewhere
- Where authoritative information lives (repos, Jira boards, Confluence spaces, Slack channels)
- How to advise on different types of questions (technical Q&A, document drafting, status reporting)
- What rules to follow (sensitive-data handling, human review requirements, factual precision)

The agent's knowledge lives in **structured markdown files** alongside its skill file. These files are the agent's memory across sessions — whenever you learn something new, the knowledge files get updated.

A **hub CLAUDE.md** is the router — it sends questions to the right agent and carries shared context and ambient guardrails. The enforcement point is the agent definition itself: every agent bootstraps the operating protocol (learning loops, triage policy, knowledge schema) from the second-brain skill as its first action, so the discipline travels with the agent rather than depending on which directory a session starts in.

## Architecture: Hub and Spoke

```
Your Project or Vault/
├── CLAUDE.md                    ← Router + shared context (hub)
│   ├── Agent routing table      ← "If about X, load agent Y"
│   ├── Shared context           ← Org, program, key repos
│   ├── Protocol pointer         ← Loaded from the skill, not restated
│   └── Ambient guardrails       ← privacy, citing, human review
│
├── Domain A/
│   ├── domain-a-agent.md        ← Agent skill file (procedural knowledge)
│   ├── overview.md              ← Domain facts (semantic knowledge)
│   ├── stakeholders.md          ← People, roles, contacts
│   └── lessons-learned.md       ← Past incidents/decisions (episodic knowledge)
│
├── Domain B/
│   ├── domain-b-agent.md
│   ├── overview.md
│   └── ...
│
└── _Templates/
    └── agent-template.md        ← Gold-standard agent skeleton
```

## The Flywheel

The system has four reinforcing loops that make it continuously more valuable:

### Loop 1: Use → Learn
Every session with a domain agent produces new knowledge. You discover a new stakeholder, learn about a process change, find a document you didn't know existed, or get feedback on a submission.

### Loop 2: Learn → Persist
The contribution reflex and task-completion gate push discoveries into knowledge files as the work happens. This is enforced through the agent definition — every agent bootstraps the operating protocol from the skill at session start, so persistence isn't optional. The test: "If a brand new Claude session started right now and loaded only the knowledge files, would it have all the context it needs?"

### Loop 3: Persist → Share
When you discover a pattern, connector, or workflow that would help others, it gets promoted upstream into a shared skill — not kept as a local workaround. Local fixes help one person; skill improvements help everyone.

### Loop 4: Share → Use
Shared skills (Slack connectors, Jira MCP tools, document generators) make everyone's agents more capable. More capability → more usage → more learning → the flywheel accelerates.

## Core Principles

### Reference, Don't Duplicate
Knowledge files point to sources of truth — they don't copy content from them. Point to a project board by URL, not by pasting task descriptions. This keeps knowledge fresh because the source of truth is always the live system.

**Do this:**
```markdown
## Home Projects
- Project board: {Todoist project URL}
- Query current tasks via the Todoist MCP
```

**Not this:**
```markdown
## Current Tasks
- Replace water heater (In Progress)
- Regrout shower (Done)
```

### Index Layer, Not Content Repository

The Second Brain is a **navigation layer** — not a content store. Each layer is progressively more compact than the one below:

| Layer | Target Size | Purpose |
|---|---|---|
| Hub CLAUDE.md | < 200 lines | Route to correct domain in seconds |
| Agent skill file | < 300 lines | Load scope, routing, modes in under a minute |
| Knowledge file | < 200 lines each | Scan curated facts + pointers quickly |
| Vault content | No limit | Full documents, read on demand |

If a knowledge file exceeds 200 lines, it has likely grown beyond an index into a content repository. Extract the content to its natural home in the vault and replace it with a pointer.

### Three-Tier Memory Taxonomy
Different kinds of knowledge need different update strategies:

- **Procedural memory** = the agent skill file itself. How to behave, what tools to use, what to delegate. Changes rarely — only when the agent's responsibilities change.
- **Semantic memory** = knowledge files. Facts about accounts, systems, people, processes. Changes when the domain evolves.
- **Episodic memory** = lessons learned, decision records, incident post-mortems. Grows over time, rarely revised.

### Temporal Annotations
Every fact should carry a timestamp so you know when it was learned and when to check if it's still true:

```markdown
- Ship date: Jul 1-15 (hard deadline: Jul 15) [learned: 2026-03-15] [review-by: 2026-05-01]
- Primary care physician: Dr. Alvarez [learned: 2026-03-30]
- Primary care physician: Dr. Chen [superseded: 2026-03-30, replaced by Dr. Alvarez]
```

### Confidence Scoring

Every knowledge file carries a file-level confidence rating in its frontmatter:

- **high** — all entries verified against primary sources (code, official docs, direct conversation)
- **medium** — reported by a credible source but not independently verified (Slack message, meeting notes, second-hand)
- **low** — inferred, estimated, or from an unverified source

For high-stakes entries (schedule dates, risk assessments, compliance claims), add an inline tag: `[confidence: medium]` alongside the `[learned: YYYY-MM-DD]` tag.

**Agent behavior:** When generating outward-facing or high-stakes outputs, flag any `confidence: low` entries with a caveat or omit them entirely.

### Knowledge Decay Classification
Not all knowledge ages at the same rate:

- **Fast decay** (days/weeks): Sprint status, ticket states, deployment versions, action items. Check every session.
- **Medium decay** (months): Architecture decisions, team composition, process definitions. Check monthly.
- **Slow decay** (years): Program objectives, compliance frameworks, organizational structure. Check quarterly.

**How to tag decay rate:**

- **YAML frontmatter** (preferred): Use `decay: fast|medium|slow` in files that support frontmatter — knowledge files, agent files, any markdown with a `---` header block.
- **HTML comment fallback**: Use `<!-- decay: fast|medium|slow -->` on line 1 for files that cannot or should not have YAML frontmatter — hub CLAUDE.md files, rules files, convention docs, or any markdown where frontmatter would interfere with rendering. The audit recognizes both formats identically.

Use YAML frontmatter when the file already has structured metadata (knowledge files always do). Use HTML comments for everything else. Both are machine-readable; the goal is coverage, not uniformity.

### Mechanical Staleness Detection

Temporal annotations catch **knowledge decay** (facts getting old). Mechanical staleness catches **sync drift** (source changed, knowledge file didn't).

The system uses a `.staleness-manifest.json` at the Second Brain root that tracks source fingerprints. Each knowledge file can declare `sources:` in its YAML frontmatter — URLs and paths to the external resources it indexes. On each audit run:

1. **Seed** (first run or new sources): Snapshot fingerprint (file count, mtime, issue count, page version) into the manifest
2. **Check** (subsequent runs): Re-fingerprint and compare. If source changed but knowledge file's `last_updated` hasn't moved, flag as **sync-stale**
3. **Resolve**: When the knowledge file is updated after reviewing the source, the sync flag clears

This complements annotation-based staleness — together they catch both "this fact is old" and "the source changed and nobody told us."

### The Ecosystem
Every content source connector — Slack skills, Jira MCP, Confluence MCP, Outlook integrations — is a community asset. When you find a gap (a Yellow or Red readiness source), the right response is to improve the shared tool, not build a local workaround. This is Loop 3 of the flywheel in action.

## Maturity Levels

| Level | Name | What It Looks Like |
|-------|------|-------------------|
| **L1** | Basic | Single agent, 1-2 knowledge files, no workflows, no temporal annotations |
| **L2** | Structured | Agent follows the template (including the protocol bootstrap), 3+ knowledge files with temporal annotations, hub CLAUDE.md with routing |
| **L3** | Connected | Agent delegates to/from other agents, multiple content sources wired up, repeatable workflows defined |
| **L4** | Disciplined | Retrospection loops holding via the bootstrapped protocol, audits pass clean, knowledge freshness actively tracked |
| **L5** | Evolving | Contributing improvements upstream to shared skills, collector-based automation pipelines, archive lifecycle for completed work |

Most engineers should target L2 within a week and L3 within a month. L4-L5 emerge naturally as the flywheel accelerates.

## Getting Started

Run `/second-brain create` to begin. The skill will walk you through an interactive interview and generate everything you need.
