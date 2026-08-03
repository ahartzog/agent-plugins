# Create Mode — Full Interview & Generation Flow

This document guides the Create mode of the `second-brain` skill. Follow these steps exactly.

## Prerequisites

Before starting, the SKILL.md has already run:
- Environment detection (Obsidian mode vs. plain mode)
- Hub discovery (existing hub found, or need to create one)

## Step 1: Show What Exists (if hub found)

If an existing hub CLAUDE.md was found:

1. Read it and extract the agent routing table
2. Show the user: "Found your Second Brain hub at `{path}` with these agents: {list}"
3. **Check for pre-2.0 protocol restatement** before proceeding: grep the hub CLAUDE.md for restated behavior rules (`grep "Loop A\|Self-Awareness\|auto_contribute" CLAUDE.md`) and check whether a `protocol/` folder exists at the hub root. If either hits, the hub predates the single-sourced protocol — offer to migrate it per `references/migration.md` before adding the new agent. If the user declines, proceed, but note that the new agent will load the current protocol while the hub restates a stale copy.
4. Ask: "Want to add a new domain agent to this hub?"

If no hub found:
1. Tell the user: "No Second Brain hub found. I'll create one as part of this process."

## Step 2: Domain Interview

Ask these questions **one at a time** using `AskUserQuestion`. Do not skip questions, but adapt phrasing to context.

### Q1: Domain Name
"What domain does this agent cover? This should be a program name, team name, or functional area."

Examples: "Household Finances", "Family Concierge", "Home & Property", "Health & Benefits", "Career", "Side Project X"

Store as `{domain_name}`. Derive `{domain_slug}` as kebab-case (e.g., "Household Finances" → "household-finances").

### Q2: Scope
"What is this agent's scope? What questions should it answer, and what should it tell the user to ask elsewhere?"

Guide: The best agents have clear boundaries. "Everything about X" is too broad. "Ground segment software delivery for X, excluding orbital and hardware" is well-scoped.

Store as `{scope}`.

### Q3: Agent Type

Options:
- **Advisory** — Answers questions, drafts documents, provides analysis. Most common. Good default for programs and teams.
- **Orchestrator** — Runs workflows, dispatches sub-agents, automates recurring operations. For automation-heavy domains.
- **Hybrid** — Does both. For mature domains with both Q&A and automation needs.

Store as `{agent_type}`.

### Q4: Sources of Truth

Read `references/content-sources.md` and present the source catalog grouped by readiness (Green first, then Yellow). For each source, ask if it's relevant to this domain.

Use multi-select. Let the user check all that apply.

For each selected source, gather specifics appropriate to its type (per the catalog's "How Sources Wire to Agents"):
- **MCP-backed sources** (Monarch, Google Workspace, trackers, wikis): which accounts/boards/spaces/calendars? Note the fully-qualified tool prefix
- **File-based sources**: which folder paths? Is there a raw/immutable layer to protect?
- **Manual/export sources** (MyChart, portals): export procedure + where exports land
- **Other**: URL or description

Store as `{sources}` — a list of `{type, details}` pairs.

### Q4.5: Capabilities (Before/After)

"What are the 2-5 key capabilities this agent delivers? Think in **Before/After** terms — what does a user struggle with today that this agent makes easy?"

**Why this matters:** Capabilities are the organizing principle for the "How to Advise" section and the agent's intro. They answer "why does this agent exist?" — not just "what does it do?" An agent framed around capabilities is more focused and more useful than one framed around question types alone.

**Example:**

| Capability | Before | After |
|-----------|--------|-------|
| Implicit cross-service context | Engineer manually declares which services are in scope every session | Agent infers from dependency graph — one question surfaces the whole context |
| Onboarding acceleration | New engineer gets pointed at a 200-page wiki | "Start here. This is the pattern. These are the gotchas." |

If the user struggles to articulate capabilities, prompt: "Imagine someone who uses this agent daily. What frustration from last week would they no longer have?"

Store as `{capabilities}` — a list of `{name, before, after}` triples.

### Q5: Question Types

"What kinds of questions will people ask this agent?"

Options (multi-select):
- **Technical Q&A** — "How does X work?", "Where is the code for Y?"
- **Document Drafting** — "Write an RFC for Z", "Draft a status update"
- **Status Reporting** — "What happened this week?", "What's the current state of X?"
- **Meeting Prep** — "Prepare briefing notes for the CDR review"
- **Stakeholder Briefing** — "Summarize this for leadership"
- **Compliance/Review** — "Check if we meet requirement X", "Generate BOE artifact"
- **Other** — let user describe

Each selected type maps to a "How to Advise" mode in the generated agent. Store as `{question_types}`.

### Q6: Output Audiences

"Who sees this agent's output?"

Options (multi-select):
- **Just me** — no special handling needed
- **Household/team** — shared with family or teammates; keep gift-confidentiality-style partitions in mind
- **External parties** — contractors, schools, vendors, clients; needs formality, human review, optional voice skill
- **Regulated/sensitive context** — government, compliance, legal; conservative handling, strict sourcing

Store as `{audiences}`. This determines:
- Whether sensitive-data rules are included
- Whether human review is mandatory before sharing (External/Regulated)
- Voice and formality level guidance

### Q7: Related Agents

"Does this agent delegate to or receive delegation from other agents in your hub?"

If hub has existing agents, show the list and ask about relationships:
- "Should this agent delegate X-type questions to {existing_agent}?"
- "Should {existing_agent} delegate Y-type questions to this new agent?"

If no hub or no existing agents, skip this question.

Store as `{delegations}` — list of `{direction, agent, topic}` triples.

### Q8: Workflow Needs (optional)

"Does this domain need any repeatable workflows? (You can always add these later with `/second-brain add-workflow`)"

Read `references/workflow-patterns.md` and present the pattern catalog briefly:
- Status Report (5-15)
- Collector Pipeline
- RFC/Document Authoring
- Compliance Scanning
- Schedule Assessment
- Sprint Orchestration

If the user selects one, note it for post-creation follow-up. Do NOT generate the workflow inline — finish creating the agent first, then offer to run `/second-brain add-workflow`.

## Step 3: Generate Files

Using the interview answers, generate the following files:

### 3a: Agent Skill File

Read `assets/agent-template.md` and fill in the placeholders:

- `{DOMAIN_NAME}` → `{domain_name}`
- `{DOMAIN_SLUG}` → `{domain_slug}`
- `{SCOPE_SENTENCE}` → `{scope}`
- `{DESCRIPTION}` → one-line summary derived from domain_name + scope
- Tools list: use the template's default set. `Skill` must stay in `tools:` — the Bootstrapping block depends on it — and keep `Agent` where needed (Orchestrator dispatch, subagent contributions).
- **Bootstrapping block**: carry the template's `## Bootstrapping — Required, Every Session` block through verbatim and unconditional — do not soften it to "consider invoking". Fill `{AUTO_CONTRIBUTE}` to match the frontmatter value (declare `auto_contribute: false` in frontmatter for new agents) and `{SKILL_INSTALL_POINTER}` with the install commands (`claude plugin marketplace add ahartzog/agent-plugins` then `claude plugin install second-brain@ahartzog`). This block is how the agent loads the operating protocol from the skill; nothing else in the file substitutes for it.
- **Guiding Principles** section: draft 3-7 judgment principles from the interview (scope boundaries, what dominates decisions in this domain, when to pull live data). These are how-to-decide statements, not procedures — see the template's good/bad examples. Tell the user these will sharpen over time via Loop E.
- **Knowledge Files** table: one row per knowledge file, phrased as the question it answers; add delegation lines for related agents
- **Domain Context** section: populate with source details (MCP tool prefixes, folder paths, board/space/account identifiers) and a Known Quirks subsection (empty at creation — Loop B fills it)
- **Five Capabilities** section (generated from Q4.5): add a capabilities table near the top of the agent file, after the Bootstrapping block and before Guiding Principles. Format as:
  ```
  ## Capabilities
  | # | Capability | Before | After |
  |---|-----------|--------|-------|
  {one row per capability from Q4.5}
  ```
  This makes the agent's purpose explicit at a glance and anchors all advice in user outcomes.
- **How to Advise** section: organize subsections around capabilities first, then question_type modes. For each capability, write a "How to deliver [capability name]" block that maps it to the relevant sources, routing rules, and output format.
- **Output Format** section: generate format templates appropriate for the audiences
- **Rules** section: keep the template's no-restatement preamble and its domain-rules-only standard set (never fabricate; cite sources; prefer shared improvements; external-systems confirmation gate). Fill `{EXTERNAL_SYSTEMS}` from the selected sources. Add the domain disclaimer for financial/medical/legal domains, and the human-review rule for External/Regulated audiences. Keep hard constraints only — soft guidance goes in Guiding Principles. Do **not** write a Self-Awareness Protocol section, a Contribution Gate rule, or temporal-annotation/supersede rules into the agent file — those come from the protocol layer via the bootstrap, and a local copy drifts.
- **Replace all `{DOMAIN_FOLDER}` path placeholders** throughout the generated file with the actual domain folder path rooted at the hub directory. This is critical — agents live in subdirectories and bare relative paths won't resolve.
- **Ensure `Agent` is in the tools list** — needed for subagent dispatch on complex multi-file contributions.

Write to: `{hub_dir}/{Domain Name}/{domain_slug}-agent.md`
(where `{Domain Name}` is title-cased for the folder name)

### 3b: Starter Knowledge Files

Always create:

**`overview.md`**
```markdown
<!-- decay: medium -->
# {Domain Name} — Overview

## Scope
{scope}

## Key Systems
<!-- Populate with the systems, repos, and tools relevant to this domain -->

## Architecture
<!-- Add high-level architecture notes as you learn them -->

## Key Links
<!-- Add Jira boards, Confluence spaces, Slack channels, repo URLs -->
{populated from sources interview}
```

**`stakeholders.md`**
```markdown
<!-- decay: medium -->
# {Domain Name} — Stakeholders

## Key People
<!-- Add people, roles, and contact info as you discover them -->
| Person | Role | Contact | Notes |
|--------|------|---------|-------|
| | | | |

## Teams
<!-- Which teams interact with this domain? -->

## Decision Authority
<!-- Who approves what? -->
```

Always create **`index.md`** — the domain inventory (source of truth for what's in this folder):

```markdown
---
domain: {domain_slug}
type: index
description: "Inventory of every file in {Domain Name}/ — what it answers, when last updated"
decay: medium
confidence: high
last_updated: {today}
---

# {Domain Name} — Index

| File | What it answers / contains | Updated |
|------|---------------------------|---------|
| `{domain_slug}-agent.md` | The agent | {today} |
| `overview.md` | Current snapshot + key risks | {today} |
| `stakeholders.md` | People, roles, contacts | {today} |
```

The owning agent updates this whenever files are added or restructured; the custodian diffs it against disk. The hub CLAUDE.md lists agents only — never per-file inventories.

Always create **`reference-library.md`**:

```markdown
---
domain: {domain_name}
type: reference-library
description: Corpus index for {domain_name} — retrieval triggers for documents the agent can load
decay: slow
confidence: high
last_updated: {today}
---

# {Domain Name} — Reference Library

## Scope

{2-3 sentences describing what topic area this sub-library covers — used by the agent for first-pass relevance filtering}

*This file is auto-discovered. Add entries here to make documents findable by the agent — no other registration required.*

---

## {Category}

| Topic | Source | Triggers |
|---|---|---|
| {short entry name} | {vault path | drive path | external URL, with § section when applicable} | {comma-separated phrases/keywords that should match} |
```

The `Topic | Source | Triggers` table is the default entry format (`protocol/knowledge-schema.md` § Reference Library Entry Format). For the rare entry that needs a sentence of routing context, use the block escape hatch — `### {entry-name}` / `**Source:**` / `**Triggers:**` / one `**Note:**` line — and keep the file under the 200-line cap.

If Compliance/Review is a question type, also create **`compliance-status.md`**.
If the domain has a specific project/program, also create **`schedule.md`**.
If the domain has external documents to catalog (SharePoint, Confluence, vendor deliverables), create a **`document-catalog.md`** with `type: index`. Use `doc_type` and `authority` columns in catalog tables per `references/document-quality.md`.

All generated knowledge files MUST include YAML frontmatter schema:
- `domain`: from interview Q1
- `type`: `overview.md` → reference, `stakeholders.md` → register, `compliance-status.md` → status, `schedule.md` → status
- `description`: generated from interview context
- `decay`: reference → medium, register → medium, status → fast
- `confidence`: medium (new agent, not yet battle-tested)
- `last_updated`: today's date
- `sources:` array pre-populated from interview Q4 answers (Jira project keys → jira-board entries, Confluence spaces → confluence-page entries, repo paths → git-repo entries, OneDrive folders → directory entries)

**Decay tagging for non-frontmatter files:** The hub CLAUDE.md file, rules files, and other structural markdown that cannot have YAML frontmatter should use an HTML comment on line 1 instead: `<!-- decay: medium -->`. The audit and custodian recognize both YAML `decay:` fields and HTML comment decay tags. See `references/framework.md` → Knowledge Decay Classification for the full policy.

### 3c: Hub CLAUDE.md

If creating a new hub, read `assets/hub-template.md` and generate it with:
- The new agent in the routing table
- Shared context populated from the interview
- The template's standard sections (Operating Protocol pointer, Ambient Guardrails, Domain Index Convention, Local Knowledge Policy, Contribution Settings, custodian and golden-questions notes)

**Do not write protocol content or agent behavior into the hub CLAUDE.md.** It holds routing, shared context, and ambient guardrails only — it does not enforce behavior across sessions. The loops, triage categories, and knowledge schema load from this skill via each agent's bootstrap; behavioral rules live in the agent definition, which is read on every invocation. The hub CLAUDE.md reliably loads only when the session's working directory is the hub — on file-path, slash-command, or skill-shim invocation it arrives incidentally at best, never something enforcement may depend on.

**Domain-level CLAUDE.md:** if the new domain is a single self-contained folder — especially one that will be shared externally (synced to a collaborator, split into its own repo) — also generate `{hub_dir}/{Domain Name}/CLAUDE.md` from `assets/domain-claude-md-template.md`. It is a signpost to the agent definition plus a short ambient-guardrail list, not a rulebook. Fill its Ambient Guardrails from the interview's sensitivity answers (Q6 audiences — e.g., Regulated/sensitive → a PII-handling rule; keep it to 5 or fewer) and its Dependencies section with the skill install pointer (`claude plugin marketplace add ahartzog/agent-plugins` then `claude plugin install second-brain@ahartzog`) — every maintainer of the folder needs the skill, since the protocol is not restated anywhere in the folder.

If appending to an existing hub:
- Add the new agent to the routing table
- Add any new shared context if the domain introduces new tools or sources
- If Step 1's check found protocol restatement or a hub-root `protocol/` folder and migration was deferred, remind the user once more that `references/migration.md` applies — do not rewrite the hub's existing sections without approval

### 3d: Obsidian Landing Page (Obsidian mode only)

If in Obsidian mode, create `{hub_dir}/{Domain Name}/{Domain Name}.md`:

```markdown
# {Domain Name}

> Agent: [[{domain_slug}-agent]]

## Knowledge Base
- [[overview]]
- [[stakeholders]]
{additional knowledge file links}

## Quick Links
{Jira board links, Confluence space links, etc. from sources}
```

### 3e: Skill Registration & Slash Command

Make the persona immediately invokable as a slash command. This is critical for adoption — if users can't type `/{domain-slug}` to invoke their persona, they won't use it interactively.

**Step 1: Create a local skill entry.**

Create `~/.claude/skills/{domain-slug}/SKILL.md`:

```markdown
---
name: {domain-slug}
description: "{domain_name} domain persona — {one-line scope}. Use when working on {domain_name} topics."
---

Read the persona file at `{absolute_path_to_agent_file}` and follow its instructions. Load the knowledge files it references before answering any question.
```

This registers the persona in Claude Code's skill system. It appears in the system-reminder skill list at session start and is invokable via the `Skill` tool automatically.

**Step 2: Create a slash command alias.**

Create `~/.claude/commands/{domain-slug}.md`:

```markdown
---
description: Invoke the {domain_name} persona
---

Use the Skill tool to invoke the `{domain-slug}` skill.
```

This makes `/{domain-slug}` available as a typed command at the prompt. Users can type `/{domain-slug}` to activate the persona explicitly.

**Step 3: Add routing to the user's global CLAUDE.md.**

Read `~/.claude/CLAUDE.md`. If it exists, offer to append a routing entry:

```markdown
## {domain_name}
If we are working on {domain_name} topics, invoke the `{domain-slug}` persona skill.
```

If `~/.claude/CLAUDE.md` doesn't exist, offer to create it with a minimal structure:

```markdown
# My Claude Workflow

## {domain_name}
If we are working on {domain_name} topics, invoke the `{domain-slug}` persona skill.
```

**Explain to the user:** "This means when you open Claude Code — from any directory — and ask about {domain_name}, Claude will automatically load your persona. You can also type `/{domain-slug}` explicitly."

**Why all three:**
- The skill entry makes the persona discoverable by Claude's skill matching
- The command alias gives users a memorable slash command
- The global CLAUDE.md routing means Claude can auto-activate without the user knowing about skills at all

### 3f: Protocol — Loaded from the Skill, Never Copied

Do **not** create a `{hub_dir}/protocol/` directory or copy any `protocol/*.md` files into the hub. The operating protocol (learning loops, triage policy, knowledge schema) loads from this skill at session start via the agent's Bootstrapping block — a hub copy freezes on the day it's written and silently drifts. If the hub already has a `protocol/` folder, that's a pre-2.0 leftover; Step 1's check offers migration per `references/migration.md`.

## Step 4: Verify & Next Steps

After generation:

1. List all files created with their paths, grouped clearly:

   **Persona files** (in your vault/repo):
   - `{hub_dir}/{Domain Name}/{domain-slug}-agent.md` — the persona
   - `{hub_dir}/{Domain Name}/overview.md` — architecture & topology
   - `{hub_dir}/{Domain Name}/stakeholders.md` — people & contacts
   - `{hub_dir}/CLAUDE.md` — hub (created or updated)
   - `{hub_dir}/{Domain Name}/CLAUDE.md` — domain signpost (if generated for a self-contained folder)

   **Invocation files** (in your Claude config):
   - `~/.claude/skills/{domain-slug}/SKILL.md` — skill registration
   - `~/.claude/commands/{domain-slug}.md` — slash command
   - `~/.claude/CLAUDE.md` — global routing (updated)

2. Show a summary: "Created {domain_name} agent with {N} knowledge files, {N} sources wired up, maturity level L1"

3. Show **how to use it** (this is the most important part for new users):
   ```
   You can now use your persona in three ways:

   1. Type /{domain-slug} at the Claude Code prompt
   2. Just ask about {domain_name} — Claude will activate it automatically
   3. Open Claude Code from your vault directory for the richest context

   Try it now: "What do I need to know about {domain_name}?"
   ```

4. Suggest next steps:
   - "Populate your knowledge files with initial domain knowledge"
   - "Run `/second-brain audit` to check your setup"
   - If workflow was requested: "Run `/second-brain add-workflow` to set up your {workflow_type} workflow"
   - If delegations were specified: "I've added delegation rules. Make sure the other agent(s) also know about this agent."
   - "When the agent has a few weeks of real sessions behind it, seed `golden-questions.md` (`assets/golden-questions-template.md`) from questions you actually asked — that's your regression signal."
   - "Your agent defaults to `auto_contribute: false` in its frontmatter — it will ask before making knowledge changes. Once you trust the agent's judgment, flip it to `true` in the YAML block at the top of the agent file — that's what makes the flywheel spin."

## Step 5: Update Existing Agents (if delegations specified)

If delegations were configured involving existing agents:

1. Read each existing agent that should delegate TO the new agent
2. Add a delegation rule where that agent keeps its routing — in template-based agents, the delegation lines under Knowledge Files; match the section by function, not by name: "If the question is about {topic} → delegate to {new_agent}"
3. Confirm the change with the user before writing
