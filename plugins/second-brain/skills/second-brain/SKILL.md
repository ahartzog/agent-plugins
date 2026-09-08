---
name: second-brain
description: Create, adopt, audit, and improve domain-focused AI agents with persistent knowledge files and self-reinforcement loops. Use when the user wants to set up a Second Brain, create or adopt a domain agent, audit their knowledge base, improve an existing agent, add a workflow, wrap a working session, or load the operating protocol. Triggers on "second brain", "domain agent", "knowledge base agent", "create agent", "adopt agent", "audit agents", "improve agent", "add workflow", "wrap the session", "did everything get persisted", "operate", "load the protocol".
model: opus
---

# Second Brain — Domain Agent Lifecycle Skill

A meta-skill for creating, adopting, auditing, and improving domain-focused AI agents with persistent knowledge files and enforced retrospection discipline.

## What This Skill Does

This skill encodes a proven operating model for AI-assisted domain knowledge management. It helps you:

1. **Operate** — load the universal operating protocol (learning loops, contribution gate, knowledge schema) into a session. This is the enforcement path every domain agent bootstraps.
2. **Create** domain agents with an interactive interview → scaffolded files
3. **Adopt** existing hand-rolled agents — bring them under management without rewriting them
4. **Audit** existing agents for consistency, freshness, loop health, and best-practice gaps
5. **Improve** agents by leveling them up against gold-standard patterns (including migrating pre-2.0 hubs — see `references/migration.md`)
6. **Add Workflows** (repeatable operations like status reports, custodian health checks, golden-question evals)
7. **Wrap** a working session — verify the conversation's learnings actually landed in the knowledge files, close the gaps, log telemetry

The skill owns the **protocol layer** — the universal rules every Second Brain runs on. It is a **hard prerequisite**: the protocol is not restated in any agent file, hub, or shared folder, so an agent without the skill has no operating protocol at all. Agent definitions hold domain behavior; a `CLAUDE.md` holds routing, shared context, and ambient guardrails.

## Mode Detection

Parse the user's input to determine the mode:

- `/second-brain operate`, "load the protocol", or a bootstrap call from an agent definition → **Operate**
- `/second-brain create` or "create an agent" or "set up a second brain" → **Create**
- `/second-brain adopt` or "adopt my agents" or "bring my existing agents under management" → **Adopt**
- `/second-brain audit` or "audit my agents" or "check my knowledge base" → **Audit**
- `/second-brain improve` or "improve this agent" or "level up" or "migrate my hub" → **Improve**
- `/second-brain add-workflow` or "add a workflow" or "repeatable operation" → **Add Workflow**
- `/second-brain wrap` or "wrap the session" or "did everything get persisted" → **Wrap**
- No mode specified → show available modes and ask which one

## Hub Discovery (required for Adopt, Audit, Improve, Add-Workflow, Wrap)

Before running any non-Create mode, locate the Second Brain hub (Operate is the exception: it locates local extensions relative to the *invoking agent definition's* file path first — see `references/mode-operate.md` Step 3 — and never prompts about a missing hub):

1. Check current working directory for `CLAUDE.md` containing an agent routing table (look for `## Available Agents` or `## Agents` or similar table with agent paths)
2. Walk up parent directories looking for the same pattern
3. If `.obsidian/` directory exists anywhere in the path, search vault root for `CLAUDE.md`
4. If no hub found → prompt: "I can't find a Second Brain hub. Would you like to create one (`/second-brain create`) or adopt an existing setup (`/second-brain adopt`)?"

Store the hub path — all subsequent operations are relative to it.

## Environment Detection (used by Create/Adopt, shared with other modes)

- **Obsidian mode:** `.obsidian/` directory exists → use wikilinks (`[[page]]`), offer to create Obsidian landing pages with embeds, use Obsidian MCP tools if available
- **Plain mode:** no `.obsidian/` → use standard markdown links, CLAUDE.md-only routing, standard file operations

## Mode Execution

### Operate Mode

Read `references/mode-operate.md` and follow its instructions. This loads the protocol layer, resolves the `auto_contribute` setting, and reads any local extensions. Domain agents bootstrap this at session start; it is plumbing and should not narrate.

### Create Mode

Read `references/mode-create.md` and follow its instructions. This runs an interactive interview and scaffolds the agent.

### Adopt Mode

Read `references/mode-adopt.md` and follow its instructions. This inventories existing hand-rolled agents and brings them under management with minimal, voice-preserving diffs.

### Audit Mode

Read `references/mode-audit.md` and follow its instructions. This examines all registered agents and produces a health report.

### Improve Mode

Read `references/mode-improve.md` and follow its instructions. This analyzes a specific agent and proposes improvements. For hubs built before protocol single-sourcing (v2.0.0), it applies `references/migration.md`.

### Add Workflow Mode

Read `references/mode-add-workflow.md` and follow its instructions. This guides adding a repeatable workflow to an existing agent.

### Wrap Mode

Read `references/mode-wrap.md` and follow its instructions. This extracts the session transcript, diffs what the session learned against the hub's knowledge files, persists the gaps per `auto_contribute`, runs the Loop E gate, and appends telemetry. Judgment stages run inline in the invoking conversation; only the mechanical harvest/diff is delegated (with the transcript digest as input).

## Protocol Layer

The protocol layer contains the **universal** operating rules — the same for every Second Brain, with no placeholders and no hub-specific content. These are compact, imperative documents: they tell agents what to do, not why. The "why" lives in the reference documents.

**Protocol files:**
- `protocol/learning-loops.md` — **The enforcement engine.** Five learning loops (corrections, discoveries, custodian, contradictions, process retrospection) plus the Self-Awareness Protocol (contribution reflex, task-completion gate) and the `auto_contribute` contribution rules.
- `protocol/triage-policy.md` — Routing rules for knowledge contributions. Defines auto-eligible vs always-prompt categories.
- `protocol/knowledge-schema.md` — Canonical frontmatter schema for all knowledge files. Required fields, type semantics, decay thresholds, reference-library entry format, inline annotations.
- `protocol/link-authoring.md` — Link grammar for cross-references between knowledge files: the three relation senses, path qualification, anchor durability, placement. **Demand-loaded** — read it when writing a link (Loop B § Connections), not every session.

**How the protocol reaches a session:** via **Operate mode**, loaded from this skill — never copied into a hub. Agent definitions bootstrap `Skill(second-brain)` with "operate" as their first action. This makes the protocol single-sourced: updating it here updates every Second Brain, with no per-hub migration.

**The agent definition is the enforcement point, not `CLAUDE.md`.** A `CLAUDE.md` reliably loads only when the session's working directory is the hub — invoked by file path, slash command, or skill shim from elsewhere, its rules arrive incidentally at best. Reading the agent definition, by contrast, *is* invocation. So behavioral rules belong in the agent file (which bootstraps the protocol); `CLAUDE.md` keeps only what a session needs *before* picking an agent, or what must hold with no agent loaded at all: the routing table, shared context, ambient guardrails (sensitivity/write-zone conventions), and folder orientation. For a domain folder, `assets/domain-claude-md-template.md` is a thin signpost to the agent file plus a short guardrail list. Protocol files are the floor; local files may add to it, never replace it — where they conflict, the protocol wins (a Loop C signal).

**Contribution model:** the **Self-Awareness Protocol** — the continuous contribution reflex and the task-completion gate, including the Loop E retrospection questions — lives in `protocol/learning-loops.md` and is loaded by Operate mode, not restated in agent files. When the reflex fires, the agent reads `auto_contribute` from its own YAML frontmatter: `true` writes directly, `false` surfaces proposals. See `assets/contribution-agent-prompt.md` for the legacy subagent prompt template (retained for complex multi-file contributions where context isolation is helpful).

## Reference Materials

The reference layer contains teaching documents, design rationale, and catalogs. These are demand-loaded by specific modes — not loaded every session.

- `references/framework.md` — The philosophy behind the Second Brain operating model.
- `references/content-sources.md` — Catalog of available content sources with readiness indicators and access methods. **Personalized per hub** — regenerate for each context.
- `references/workflow-patterns.md` — Catalog of repeatable workflow patterns with examples (including custodian health pulse, golden-question eval, correction mining, session-end wrap).
- `references/maturity-model.md` — L1-L5 maturity progression for measuring agent sophistication.
- `references/learning-loops.md` — **The reinforcement model (design rationale).** The teaching document for the five feedback loops. The compact operational version is `protocol/learning-loops.md`.
- `references/link-graph.md` — **Why knowledge files link to each other.** Rationale for `protocol/link-authoring.md`, Loop B § Connections, and the Link Graph Health audit step: what links buy an agent and what they demonstrably don't, why traversal is the trigger, why this is a Loop B sub-block rather than a sixth loop, why the topology is a star and not a clique, and why edge count is never a health score. Read when changing any of them.
- `references/enforcement-hooks.md` — When and how to back loop discipline with Claude Code hooks instead of prompt text. Hooks guarantee; prompts suggest.
- `references/document-quality.md` — Quality criteria for knowledge files.
- `references/migration.md` — **Upgrading a pre-2.0 Second Brain.** Diagnose and fix hubs created before the protocol was single-sourced: add the operate bootstrap, move behavior out of `CLAUDE.md`, strip duplicated rules. Read when `audit` reports a missing bootstrap or protocol duplication.

## Templates & Scripts

- `assets/agent-template.md` — Domain agent definition. Carries the operate bootstrap, guiding principles, routing, and domain-specific rules only.
- `assets/hub-template.md` — Hub `CLAUDE.md`: routing table, shared context, local policy. No protocol content.
- `assets/domain-claude-md-template.md` — Domain-folder `CLAUDE.md`: a thin signpost to the agent definition plus ambient guardrails. Use for a single-domain folder, especially one shared externally.
- `assets/workflow-template.md` — Repeatable workflow scaffold.
- `assets/golden-questions-template.md` — Per-domain eval-set scaffold (regression harness for agent quality).
- `assets/contribution-agent-prompt.md` — Legacy subagent contribution prompt.
- `assets/pre-push-sentinel.sh` + `assets/sentinel-patterns.json` — Fail-open credential/PII pre-push gate for auto-pushing vaults (`references/enforcement-hooks.md` recipe 4).
- `scripts/extract_session.py` — Parses the Claude Code session transcript into a wrap-mode digest (survives context compaction). `--read-manifest [HUB_PATH]` additionally emits the markdown files the session opened, which is what feeds wrap's Connections bucket.
- `scripts/link_inert_refs.py` — Converts inert filename references (`` `foo.md` ``, "see foo.md") into real links. Dry-run by default; `--apply` writes. Refuses ambiguous basenames and lists them for a human. Exit code 0 means it found work, 1 means none.

## Key Principles

1. **The reinforcement loops are the system.** Everything else — templates, audits, maturity scores — exists to serve the five learning loops. If the loops work, the system compounds. If they don't, you have static files that decay. See `protocol/learning-loops.md` for enforcement, `references/learning-loops.md` for rationale.
2. **The contribution reflex is a structural obligation, not optional self-reflection.** Before moving to the next task, evaluate whether knowledge was produced. The difference between a static knowledge base and a compounding one is whether this fires reliably.
3. **Principles over procedures.** Agent files teach judgment — how to decide — with worked examples. Numbered steps are reserved for genuinely fixed procedures (MCP call sequences, confirmation gates, regulatory checklists).
4. **`auto_contribute` is a trust dial.** New setups default to `false` (user approves each change). Once trust is established, switch to `true` — agents write directly, report at session end. Contradictions and structural changes always prompt regardless.
5. **Reference, don't duplicate.** Knowledge files point to sources of truth (live MCP data, external docs, repos) — they don't copy content.
6. **Obsidian-aware but not required.** The system works in any directory. Obsidian adds nice-to-haves.
7. **Every gap is an improvement opportunity.** Yellow/Red readiness sources in the catalog are connectors that could be better. Improve and contribute back.
8. **The skill owns the protocol; the agent definition enforces it; CLAUDE.md owns what's local.** Universal rules are loaded from this skill via Operate mode so every hub runs the current version — restated protocol freezes on the day it was written; loaded protocol updates everywhere at once. A hub `CLAUDE.md` carries routing, shared context, and ambient guardrails, and may extend the protocol, never restate or replace it. For discipline that MUST fire deterministically, add hooks (`references/enforcement-hooks.md`).
9. **Temporal annotations are the atomic unit of freshness.** Every fact gets `[learned: YYYY-MM-DD]`. Without this, staleness detection is impossible. Decay rates are domain-differentiated — uniform review cadences are the primary cause of wasted review cycles.
10. **Both phases, always.** Continuous (contribution reflex) → task completion (retrospection gate). If either is skipped, the loops degrade silently. Freshness inventories are an audit concern, not a per-session one — they don't belong on the hot path.
11. **Never silently overwrite.** Updates that change an existing fact mark the old value `[superseded:]` and show the diff. Confident incorrectness — "I updated X" when it didn't, or overwriting a right value with a wrong one — is the #1 trust killer for personal AI systems.
