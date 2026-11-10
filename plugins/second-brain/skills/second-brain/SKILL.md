---
name: second-brain
description: Create, adopt, audit, and improve domain-focused AI agents with persistent knowledge files and self-reinforcement loops. Use when the user wants to set up a Second Brain, create or adopt a domain agent, audit their knowledge base, improve an existing agent, add a workflow, wrap a working session, or load the operating protocol. Triggers on "second brain", "domain agent", "knowledge base agent", "create agent", "adopt agent", "audit agents", "improve agent", "add workflow", "wrap the session", "did everything get persisted", "operate", "load the protocol".
model: opus
---

# Second Brain — Domain Agent Lifecycle Skill

A meta-skill for creating, adopting, auditing, and improving domain-focused AI agents with persistent knowledge files and enforced retrospection discipline.

## What This Skill Does

This skill encodes a proven operating model for AI-assisted domain knowledge management. It helps you:

1. **Operate** — load the operating protocol (one file, `protocol/operating-protocol.md`) into a session. This is the enforcement path every domain agent bootstraps.
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

The protocol layer holds the **universal** operating rules: the same for every Second Brain, with no placeholders and no hub-specific content.

**One file is loaded every session:**
- `protocol/operating-protocol.md` — what the knowledge files are for, the three kinds of content (state, log, analysis), capture, matching the write to the commitment, what to do when a fact changes, how far to trust what is read, multi-day efforts, changing an agent's behavior, and what needs the owner's yes. Rules carry their reasons, because an agent that knows why a rule exists applies it to cases the rule did not name.

**Three files are demand-loaded:**
- `protocol/knowledge-schema.md` — frontmatter schema and inline annotations. Read when creating a knowledge file or auditing.
- `protocol/link-authoring.md` — link grammar. Read when writing a link.
- `protocol/triage-policy.md` and `protocol/learning-loops.md` — the two-class write/ask rule with the tag vocabulary, and the five loop names. Wrap, audit, and custodian workflows read these for the labels they use in ledgers and reports.

**How the protocol reaches a session:** via **Operate mode**, loaded from this skill and never copied into a hub. Agent definitions bootstrap `Skill(second-brain)` with "operate" as their first action. Updating the protocol here updates every Second Brain, with no per-hub migration.

**Precedence:** operating protocol → agent definition (domain behavior) → `CLAUDE.md` (routing, shared context). A local file may add a stricter rule for its own folder, and the stricter rule holds. A local file that restates or contradicts the protocol is stale.

**Lifecycle modes and the 3.0 protocol.** Create, adopt, audit, improve, add-workflow and wrap were written against the 2.x protocol and still use its vocabulary (loops A-E, triage tags, decay tiers). That vocabulary remains defined in the demand-loaded files above. Where a mode file's wording about in-session behavior differs from `protocol/operating-protocol.md`, the operating protocol wins.

**The agent definition is the enforcement point, not `CLAUDE.md`.** A `CLAUDE.md` reliably loads only when the session's working directory is the hub. Reading the agent definition, by contrast, *is* invocation. So behavioral rules belong in the agent file (which bootstraps the protocol); `CLAUDE.md` keeps only what a session needs before picking an agent, or what must hold with no agent loaded at all: the routing table, shared context, ambient guardrails, and folder orientation.

**Testing a protocol change:** `tests/protocol-scenarios.md` is a regression set of scripted conversations with expected behavior. Run it before changing the protocol or an agent template.

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

1. **The knowledge base exists so a future session can answer correctly and trust what it reads.** Everything else — loops, templates, audits, maturity scores — serves that. A smaller knowledge base that is right beats a larger one that is mostly right.
2. **Capture happens in the turn that produced the knowledge.** Sessions end without warning, so nothing is deferred to "the end", and every write is reported so the owner never has to ask whether it was saved.
3. **Principles over procedures.** Agent files teach judgment — how to decide — with worked examples. Numbered steps are reserved for genuinely fixed procedures (MCP call sequences, confirmation gates, regulatory checklists).
4. **`auto_contribute` is a trust dial.** New setups default to `false` (the owner approves changes, apart from log entries they dictate). Once trust is established, switch to `true`. Conflicts, restructuring and rule changes wait for a yes under either setting.
5. **Reference, don't duplicate.** Knowledge files point to sources of truth, and each piece of state has one owning file that others link to. A value copied into five files is five things to correct.
6. **Obsidian-aware but not required.** The system works in any directory. Obsidian adds nice-to-haves.
7. **Every gap is an improvement opportunity.** Yellow/Red readiness sources in the catalog are connectors that could be better. Improve and contribute back.
8. **The skill owns the protocol; the agent definition enforces it; CLAUDE.md owns what's local.** Universal rules are loaded from this skill via Operate mode so every hub runs the current version. For discipline that must fire deterministically, add hooks (`references/enforcement-hooks.md`).
9. **Freshness means last checked against the world.** `[learned:]` records when a fact was written. `[verified: date, source]` records when it was last checked, which is what decides whether to rely on it. State, logs and dated analysis are trusted differently.
10. **Size the write to the commitment.** An idea gets a line, a decision gets a record with the owner's words, and only a commitment becomes a dated task.
11. **Nothing changes silently.** A changed fact is shown old and new in the reply, and the reason is recorded: in the commit message under git, inline as `[superseded:]` otherwise. Confident incorrectness — "I updated X" when it didn't, or overwriting a right value with a wrong one — is the #1 trust killer for personal AI systems.
