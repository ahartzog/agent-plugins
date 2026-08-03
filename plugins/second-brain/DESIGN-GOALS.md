# Design Goals

This document defines the principles and goals for the `second-brain` skill. Contributors should read this before proposing changes. If a proposed change conflicts with these goals, the conflict should be discussed explicitly — not silently overridden.

## North Star

**Make domain knowledge persistent, fresh, and composable across Claude Code sessions — for any person or team, in any directory.**

The skill succeeds when a user can set up a domain persona in minutes and immediately start getting value from persistent context. It succeeds even more when that persona gets smarter with every session without the engineer having to think about it.

> **Why "persona" and not "agent"?** In the Claude Code ecosystem, "agents" are autonomous subprocesses that execute multi-step tasks (the `Agent` tool). A *persona* is different — it's a persistent identity with domain knowledge, perspective, and rules that you consult across sessions. Personas inform and guide; agents execute. This distinction matters when composing them: a persona can dispatch agents to do work, but the persona itself is the knowledge layer, not the execution layer.

## Core Design Principles

### 1. Reference, Never Duplicate

Knowledge files must point to sources of truth — they must not copy content from them. A Jira board is referenced by URL. A Confluence space is referenced by key. A Slack channel is referenced by name. The live system is always authoritative.

**Why:** Duplicated content decays immediately. The moment a Jira ticket changes status, any copy is stale. By referencing, the persona queries the live source every time and gets current data.

**Implication for contributors:** Never add features that encourage storing copies of external data in knowledge files. Add features that make it easier to reference and query live sources.

### 2. Freshness Is a First-Class Concept

Every fact should carry a timestamp (`[learned: YYYY-MM-DD]`). Time-sensitive facts should carry a review date (`[review-by: YYYY-MM-DD]`). The system should make staleness visible and actionable.

**Why:** Knowledge without timestamps is knowledge you can't trust. The difference between "ship date is July 15" learned yesterday vs. learned 3 months ago is enormous.

**Implication for contributors:** New features should respect and extend the temporal annotation system, not bypass it. Audit checks should get stricter over time, not looser.

### 3. The Agent Definition Is the Enforcement Point

Behavioral rules live in the **agent definition**. The universal ones (five learning loops, Self-Awareness Protocol, triage policy, knowledge schema) live in this skill's `protocol/` and reach a session by being **loaded** (`/second-brain operate`), which the agent definition bootstraps as its first action. A `CLAUDE.md` carries only what a session needs *before* choosing an agent, or what must hold with no agent loaded: the routing table, shared context, ambient guardrails (sensitivity, write zones), size budgets, and folder orientation.

**Why the agent file and not CLAUDE.md:** `CLAUDE.md` auto-loads from the session's **working directory**, evaluated at session start. When an agent is invoked by file path, slash command, or skill shim from elsewhere — the usual cases — the hub's rules are not in context at start. (Empirically, current Claude Code *lazily attaches* a directory's CLAUDE.md once a file in that tree is read; that softens the failure but is undocumented behavior, arrives after the session has already begun acting, and is not something enforcement may depend on.) Reading the agent definition, by contrast, *is* invocation: nothing can use an agent without reading its definition. Enforcement belongs where it cannot be missed.

**Why loaded and not copied:** the protocol files contain no placeholders and no hub-specific content; they are identical for every Second Brain. There is no reason a hub would want a *different* protocol, only an *older* one. Restating it into each hub at creation time froze that copy: hubs generated against earlier releases silently kept running a superseded protocol while appearing healthy. Single-sourcing means updating the protocol here updates every hub, with no per-hub migration.

**Precedence:** protocol (universal floor, from the skill) → agent definition (domain behavior) → `CLAUDE.md` (routing and ambient guardrails). An agent may add domain-specific rules on top of the protocol; nothing may replace or restate it. If a local file contradicts the protocol, the protocol wins and the local file is stale — surface it as a Loop C signal.

**The skill is a hard prerequisite.** There is no fallback protocol, deliberately. The loops and schema exist only in `protocol/` — no agent file, hub, or shared folder restates them, because a local copy drifts and a drifted copy is worse than none. An agent without the skill has no operating protocol at all, not a reduced one. Correct behavior is to fail visibly: say so once, answer from the knowledge files (retrieval needs no protocol), and surface findings as plain text rather than writing. This holds for externally-shared folders too: make the skill a stated prerequisite rather than shipping a restatement beside the content. Migration guidance for pre-2.0 hubs is in `references/migration.md`.

**Implication for contributors:** universal behavioral rules belong in `protocol/`, loaded via Operate mode. Domain-specific behavior belongs in the agent definition. Only local, agent-independent content belongs in the CLAUDE.md templates. Never add protocol content or behavioral rules to the hub template — that reintroduces both failure modes this goal exists to prevent. Agent definitions must bootstrap Operate mode with an unconditional instruction; hedged phrasing makes protocol loading discretionary. For discipline that must fire *deterministically* (not just reliably), hooks remain the escalation path (`references/enforcement-hooks.md`).

### 4. Progressive Disclosure

The skill should be immediately useful at L1 (basic persona with knowledge files) and progressively more powerful as the user invests more (L2 structured → L3 connected → L4 disciplined → L5 evolving). No feature should be required to get started.

**Why:** If the barrier to entry is "learn the entire framework first," adoption will be zero. If the barrier is "answer 8 questions and get a working persona," adoption will be high.

**Implication for contributors:** New features should be additive, not mandatory. The create interview should have sensible defaults. Advanced features (collector pipelines, archive lifecycle) should be opt-in via `improve` or `add-workflow`, not forced during creation.

### 5. Obsidian-Aware, Not Obsidian-Dependent

The skill detects Obsidian vaults and adds nice-to-haves (wikilinks, landing pages, Obsidian MCP tools). But every feature must work in a plain directory with just markdown and CLAUDE.md.

**Why:** Not every engineer uses Obsidian. The core value — persistent domain personas with knowledge files — doesn't require any specific tool. Coupling to Obsidian would limit adoption.

**Implication for contributors:** Always implement the plain-markdown path first. Obsidian enhancements are wrappers around the core behavior, not alternatives to it.

### 6. Thin Router, Rich References, Compact Protocol

SKILL.md is a thin mode router (~100-150 lines). Per-mode logic lives in `references/mode-*.md`. Reference materials live in `references/`. Templates live in `assets/`. Operational enforcement rules live in `protocol/`.

**Why:** A monolithic SKILL.md would exceed practical context limits and be impossible to maintain. Progressive disclosure at the file level means Claude only loads what it needs for the current mode. Protocol files are the exception — they load every session via Operate mode, because they enforce the reinforcement loops (all five: A corrections, B discoveries, C custodian, D contradictions, E process retrospection).

**The three-layer split:** Protocol files (compact, loaded every session) tell agents *what to do*. Reference files (detailed, loaded on demand) explain *why*. Hub and domain CLAUDE.md files hold local content only — they neither reference protocol files by path (those paths don't resolve outside a skill invocation) nor restate them (that's the duplication of goal 3). The protocol arrives via Operate mode.

**`references/mode-operate.md` is hot-path and must stay lean.** It loads on *every* agent invocation, so it carries only the instructions a session needs to execute: which files to read, how to resolve `auto_contribute`, which local extensions to pick up, what to report. Everything explanatory belongs here or in `references/learning-loops.md`. Target under ~70 lines.

The same discipline applies to what Operate mode loads. `protocol/` files are read into every session, so anything that isn't needed to make in-session decisions does not belong there — freshness inventories, health scans, and structural audits live in `references/mode-audit.md`. Rule of thumb: if it answers "should I write this down, and where?", it's protocol. If it answers "is this knowledge base healthy?", it's audit.

**Implication for contributors:** Add new modes as new `references/mode-*.md` files with a routing entry in SKILL.md. Don't grow SKILL.md beyond ~150 lines. If a reference file exceeds ~250 lines, consider splitting it. Protocol files should stay compact — per-file ceilings: `learning-loops.md` ≤ ~190 (five loops plus the Self-Awareness Protocol), `knowledge-schema.md` ≤ ~150 (schema plus the `[decided:]` provenance teaching), `triage-policy.md` ≤ ~110. These are actuals-plus-slack, not aspirations — a change that breaches one either trims the file or updates the ceiling here with the reason. Move rationale to references; every line added to `protocol/` is a per-session tax.

### 7. auto_contribute Is a Trust Dial

New setups default to `auto_contribute: false` (user approves every knowledge change). As users build trust in the agent's judgment, they switch to `true` (agent writes directly to knowledge files, reports at session end). Contradictions and structural changes always prompt regardless of setting.

**Why:** The full autonomous pipeline (Apiary's inbox model) is too heavyweight for single-user local agents. But pure self-discipline (agents following their own rules) is unreliable. `auto_contribute` gives users a binary between "I approve everything" and "you write directly, I review at session end" — with structural enforcement that certain categories (contradictions, custodian changes) always need human judgment. The Self-Awareness Protocol (continuous contribution reflex, task-completion gate — loaded from `protocol/learning-loops.md` via Operate mode) ensures the loops fire reliably regardless of setting — the setting only controls whether contributions are applied or proposed.

**Implication for contributors:** New triage categories should default to always-prompt until there's empirical evidence they're safe for auto-apply. The triage policy can evolve via Loop C data, but reclassifications require user approval.

### 8. Upstream Over Local

When the skill discovers a gap (missing connector, broken integration, clunky workflow), the preferred response is to improve the shared tool — not build a local workaround. This is Loop 3 of the Flywheel (Persist → Share).

**Why:** Local fixes help one hub. Shared improvements help every hub. The content source catalog explicitly marks Yellow/Red readiness sources as improvement opportunities to make this actionable.

**Implication for contributors:** PRs that improve shared connectors (MCP servers, CLI skills) are higher-value than PRs that add workarounds to this skill. When adding a workaround, include a note about the proper fix and link to an issue.

### 9. Principles Over Procedures

Agent files teach judgment — how to decide — not recipes. Numbered procedures are reserved for genuinely fixed sequences (MCP call order, confirmation gates, compliance checklists). Judgment lessons are captured as principles with worked examples attached, because an abstract rule gets rationalized away under pressure while an example with its cost attached survives.

**Why:** The most valuable agents in production are the ones whose files read like a senior advisor's judgment frames, not a call-center script. Worked examples (real failures with dates and dollar amounts) are what make corrections stick across sessions.

**Implication for contributors:** Template changes that add procedures should be challenged: is this actually a principle? Audit checks should flag procedure-creep in agent files, not just missing sections.

### 10. The Agent File Must Stay Alive (Loop E)

Loops A-D capture what the world teaches the system. Loop E captures what the system learns about itself: at every task-completion gate, agents review whether their own instructions produced a good answer, and propose revisions — including *removals*. A rule the agent worked around is a bug in the rule.

**Why:** Without proactive retrospection, agent files only change when users notice failures — and most instruction-level problems are invisible to users. Files diverge from how the agent actually operates, and dead rules accumulate until nobody trusts the file.

**Implication for contributors:** Loop E always prompts (process changes need human judgment). Telemetry (`process_revisions_proposed`) exists so audits can detect a dead reflex. Features that make agent files easier to grow but harder to shrink violate this goal.

## Content Source Catalog Rules

The content source catalog (`references/content-sources.md`) is a living document. Rules for maintaining it:

1. **Readiness levels are honest.** Green means it works reliably. Yellow means it works with caveats. Red means there's no good integration today. Don't inflate readiness.
2. **Caveats are specific.** "Requires macOS" is useful. "May have issues" is not.
3. **Improvement opportunities are explicit.** For every Yellow/Red source, describe what a better integration would look like.
4. **New sources are welcome.** If you use a tool that's not in the catalog, add it with an honest readiness assessment.

## Template Rules

The persona template (`assets/agent-template.md`) and hub template (`assets/hub-template.md`) are the most load-bearing files in the skill. Rules for modifying them:

1. **The standard functions are canonical by function, not number — and they split across two layers.** Template-carried: never-fabricate, citations, upstream preference, external-systems gate, and the operate bootstrap must survive any template change. Protocol-carried: temporal annotations, supersede-don't-overwrite, and the Contribution Gate live in `protocol/` and must NOT be restated in the templates (goal 3) — they survive via the bootstrap, not via template text. You may add template rules, but the bar is high — a new rule must apply to >50% of domains and be *domain* behavior, and Loop E's eviction discipline applies to the template too: rules that get worked around in practice get revised or removed.
2. **Placeholders use `{SCREAMING_SNAKE}` convention.** This makes them grep-able and obviously not real content.
3. **The template reflects the gold standard.** Changes should be informed by patterns that have been proven in production personas, not theoretical improvements.
4. **Backward compatibility matters.** Changes to the template should not break personas generated by earlier versions. The `improve` mode handles upgrades.

## What This Skill Is NOT

- **Not a vector database or embedding system.** Knowledge lives in readable, auditable markdown. No opaque embeddings.
- **Not automatic memory extraction.** The human-in-the-loop retrospection mandate is more reliable than automatic fact extraction. The human decides what's worth persisting.
- **Not a replacement for CLAUDE.md.** This skill generates CLAUDE.md content — it doesn't replace the existing CLAUDE.md convention. It extends it with persona routing and knowledge maintenance.
- **Not Obsidian-specific.** The skill uses Obsidian features when available but never requires them.

## Contributing

1. Read this document first.
2. Check if your change aligns with or conflicts with any design goal above.
3. If it conflicts, open the discussion explicitly in your PR description.
4. Validate JSON manifests (`python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('**/*.json', recursive=True)]"`) before pushing.
5. Test with `/second-brain create` in a clean directory AND `/second-brain adopt` against a hand-rolled hub to verify nothing breaks either happy path. For protocol or template changes, also verify an agent with the Bootstrapping block still reports `Protocol loaded: 5 loops, …` when invoked from outside its hub.
