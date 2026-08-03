# {PROJECT_NAME}

{DESCRIPTION — one-line description of what this Second Brain covers}

## Available Agents

The hub routes to agents; agents route to files. **This table is the only inventory the hub keeps** — per-file inventories live in each domain's `index.md` (the source of truth for that folder).

| Agent | Intent | Skill File | Domain Index |
|-------|--------|-----------|--------------|
{AGENT_ROWS — one row per agent: | Agent Name | one-line purpose + when to invoke | `path/to/agent.md` | `Domain/index.md` |}

## Shared Context

- **Household/Org:** {ORG}
- **Key cross-domain facts:** {SHARED_FACTS — location, family members, primary tools}
- **Live integrations:** {INTEGRATIONS — MCP servers and their status}
- **Sensitive data:** {SENSITIVITY_RULES — e.g., "This vault contains financial/medical PII. Private repo only; never share contents externally; reference external documents by path."}

## How to Use Agents

**The easiest way:** Type `/{agent-slug}` at the Claude Code prompt, or just ask about the domain — routing entries in `~/.claude/CLAUDE.md` activate the right agent automatically.

Invocation methods (in order of simplicity):
1. **Slash command:** `/{agent-slug}` — registered at `~/.claude/skills/` or `~/.claude/commands/`
2. **Automatic routing:** ask about the domain — Claude matches via `~/.claude/CLAUDE.md`
3. **Explicit skill:** use the `Skill` tool with the agent's skill name
4. **Subagent:** launch via the `Agent` tool referencing the skill file path
5. **Direct read:** read the agent file and follow its instructions (debugging fallback)

Every path converges on reading the agent definition — which is why the agent file, not this one, carries the operating rules. Agents load their own knowledge files on startup and have read+write access to update them.

## Operating Protocol — Loaded, Not Restated

The learning loops, Self-Awareness Protocol, contribution triage, and knowledge-file schema are **universal** and come from the shared `second-brain` skill, not from this file. Agents bootstrap them at session start:

```
Skill(second-brain) with "operate"
```

**This file deliberately does not restate those rules, and does not hold agent behavior.** Two reasons:

1. A copy of the protocol freezes on the day it's written — that's how hubs end up silently running a superseded protocol (missing loops, missing the `auto_contribute` gate) months after the skill moved on.
2. This file reliably loads only when a session's working directory is this hub. It does **not** dependably load when an agent is invoked by file path, slash command, or skill shim — the usual cases. Reading an agent definition, by contrast, *is* invocation. Behavioral rules therefore live in the agent file, where they cannot be missed.

What lives here is what a session needs *before* it has chosen an agent, or what must hold with **no** agent loaded: the routing table, shared context, ambient guardrails, local conventions, and size budgets.

**Precedence:** protocol (universal floor) → agent definition (domain behavior) → this file (local additions). This file may add stricter or domain-specific rules; it may not contradict the protocol. If it appears to, the protocol wins and this file needs updating — surface that as a Loop C signal.

**The skill is a prerequisite, not an enhancement.** Without it there is no operating protocol — agents answer from knowledge files but do not write to them. Install: {SKILL_INSTALL_POINTER — for this marketplace: `claude plugin marketplace add ahartzog/agent-plugins` then `claude plugin install second-brain@ahartzog`}

### Ambient Guardrails

Rules that apply to **any** session touching this directory, including hand-editing files with no agent loaded. Keep this list short — anything that only matters to an agent belongs in the agent definition.

1. **Privacy first.** Never share personal financial, medical, or legal information outside this vault. {ADDITIONAL_SENSITIVITY_RULES}
2. **Confirm before external actions.** Never modify external services ({EXTERNAL_SERVICES}) without explicit confirmation.
3. **Custodian staleness nudge.** At session start, check `_reports/` for a `custodian-*.md` dated within the last 14 days. If none found, surface a nudge to run the custodian. (For deterministic enforcement, see the hooks option in the skill's `references/enforcement-hooks.md`.)
{LOCAL_EXTENSIONS — e.g. raw-data immutability zones ("Financial/data/ and Medical/data/ are raw exports — never edit in place"), write-zone ownership, filename conventions for sensitive content. Delete if none.}

## Domain Index Convention

Each domain folder keeps an `index.md` — a thin inventory, not a content store:

- One line per file: name, what question it answers, `last_updated`
- Includes EVERYTHING in the folder (knowledge files, logs, data exports, code projects), so orphans are visible
- The owning agent updates it whenever it creates or restructures files (additive updates are auto-eligible)
- The custodian mechanically diffs disk vs. index each run — files on disk missing from the index are flagged as orphans; index entries with no file are flagged as dead links

**Why:** a central per-file index in this hub file always drifts (two places to update). The hub lists agents; the domain index lists files; the agent's Knowledge Files table maps questions to files. Three layers, each with one job. A note that isn't reachable from its domain index effectively doesn't exist — captured ≠ findable.

## Adding a New Domain

Run `/second-brain create` to add a domain agent to this hub interactively (or `/second-brain adopt` to bring an existing hand-rolled agent under management).

Or manually: create the folder, the agent definition from the agent template (with its Bootstrapping block intact), starter knowledge files (`overview.md` at minimum), an `index.md`, and a row in the routing table above. For a self-contained or externally-shared domain folder, also generate a domain `CLAUDE.md` from the skill's `assets/domain-claude-md-template.md`.

## Local Knowledge Policy

The rules for *when and how* to contribute knowledge come from the protocol (loaded via Operate mode). The items below are **local** policy for this hub.

### Size Budgets

| Layer | Target | If Exceeded |
|---|---|---|
| This file (hub CLAUDE.md) | < 200 lines | Trim; move per-file detail to domain indexes |
| Agent skill files | < 300 lines | Extract reference content to knowledge files |
| Knowledge files | < 200 lines | Split or archive; replace content with pointers |

### Archive Convention

For `status`-type files that accumulate resolved items: move closed items to an `## Archived` section rather than deleting; when that exceeds ~50 lines, extract to `{filename}-archive.md` (or the domain `_archive/` folder) and leave a pointer. Stale content gets archived, not deleted and not left rotting inline.

### What NOT to Update

- No session-specific working notes in knowledge files
- No speculative or unverified claims — confirmed facts only; mark genuinely useful-but-unverified items `[confidence: low]`
- No duplicating content that lives in a referenced document — point to it

### Content vs. Instructions

Agent definitions and rules stay **concise** — they load into context frequently. Knowledge files may be **comprehensive** — they load on demand. When a knowledge file exceeds its size budget, extract content and replace with a pointer — don't compress the content.

## Contribution Settings

Each agent's `auto_contribute` setting lives in its own frontmatter — **the frontmatter is authoritative**; any table of settings kept here is a convenience registry, not the source of truth:

- `auto_contribute: false` — agent asks before making knowledge changes (default for new agents)
- `auto_contribute: true` — agent writes auto-eligible changes directly, reports at session end. Contradictions, custodian changes, and process changes still prompt.

Switch to `true` once you trust an agent's judgment — that's what makes the flywheel spin.

## Custodian Workflow (Recommended for L3+)

A lightweight health-check workflow distinct from the full `/second-brain audit`. Create `custodian-workflow.md` at the hub root. Core checks:
1. Knowledge freshness for recently active domains; overdue `review_by` dates (offer one-click "nothing changed — extend TTL")
2. Disk vs. domain-index diff (orphans and dead links)
3. Feedback files not yet propagated (Loop A backlog)
4. Size budgets; unresolved `[disputed:]` entries (Loop D)
5. Loop telemetry append to `_reports/loop-health.json`

Output: `_reports/custodian-YYYY-MM-DD.md` + one-line summary. Run weekly (scheduled or via report workflow). The checklist GROWS via Loop C — every manual catch becomes a new check.

## Golden-Question Evals (Recommended for L4+)

Each domain keeps a `golden-questions.md` (see the skill's `assets/golden-questions-template.md`): 10-20 questions where a wrong answer matters, run quarterly in a fresh session. Failures become Loop A/B contributions and stay in the set as regression guards. This is the only objective signal that the knowledge base is compounding rather than decaying — correction frequency per session should trend down.

## Upstream Learning

**Always prefer improving shared skills over local-only workarounds.** When discovering a gap in a skill, workflow, or tool: if it would help beyond this hub, improve the shared resource (and sync it per the marketplace repo's sync discipline); if not, a local workaround is fine — but document it.
