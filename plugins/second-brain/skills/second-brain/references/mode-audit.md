# Audit Mode — Health Check & Report Generation

This document guides the Audit mode of the `second-brain` skill. It examines all agents registered in a hub and produces a structured health report.

## Safety Constraints (hard-won — apply to every audit, cleanup, or fix)

These are incident-derived. Each cost a real recovery; treat them as non-negotiable whenever an audit (or the fixes it feeds into `mode-improve`) touches files:

1. **Never delete — ever.** Cleanup means *flag for the human*, not remove. An audit that judges a file "processed" or "orphaned" flags it; it does not delete it. Archiving is a move, and only on explicit request. (An over-eager cleanup once deleted three live inbox notes it judged done; restored from git.)
2. **Never mechanically edit inside code fences or inline code.** Text within ``` fences or `backticks` is an *example*, not live content — a scanner that "fixes" it corrupts the file. (An auto-fix once wrapped a whole note body in a stray fence.)
3. **Escaped table pipes are correct.** `[[Note\|Alias]]` inside a Markdown table cell *requires* the escaped `\|`. A scanner flagging it as malformed and "fixing" it breaks the table. Do not touch escaped pipes in table cells.
4. **Never claim absence from a sampled search.** A reranked/top-N or grep-limited search returning nothing means "not in this sample," not "the vault has nothing." Absence claims (e.g. "no duplicate exists," "nothing links here") require an exhaustive scan.
5. **Mixed-author working trees get split commits.** The audit's own mechanical fixes go in a separate, honestly-labeled commit from pre-existing human or other-session edits. When authorship of an uncommitted change is unclear, don't commit it — flag it.
6. **Never bulk-shorten wiki-links (Obsidian).** Before shortening a path-qualified `[[folder/Name]]` to a bare `[[Name]]`, count basename matches vault-wide; 2+ matches → keep it path-qualified. Never run a bulk link-shortening pass — it silently re-points links at wrong same-named notes (see Wiki-Link Integrity below).

## Prerequisites

The SKILL.md has already run hub discovery and found a hub CLAUDE.md at `{hub_path}`.

## Step 1: Discover Agents

1. Read the hub CLAUDE.md
2. Extract the agent routing table (look for a markdown table with columns like Agent, Skill File, Domain)
3. For each registered agent, resolve the skill file path relative to the hub directory
4. Also scan the hub directory for `*-agent.md` and `SKILL.md` files that might NOT be in the routing table (unregistered agents)
5. Report: "Found {N} registered agents and {M} unregistered agent files"

## Step 2: Per-Agent Structural Checks

For each agent file, check the following. Track findings as `{severity, category, message, file, suggestion}`.

### YAML Frontmatter (Required for L1+)
- [ ] `name` field exists and is kebab-case
- [ ] `description` field exists and is non-empty
- [ ] `tools` field exists and is an array
- [ ] `model` field exists (should be `opus` for advisory agents, `sonnet` acceptable for orchestrators)
- [ ] `maxTurns` field exists (default 40 for advisory, up to 60 for orchestrators)

**Severity:** Critical if frontmatter is missing or unparseable. Important if individual fields are missing.

### Template Structure (Required for L2+)
- [ ] Has an identity/persona opening paragraph
- [ ] Has a knowledge-routing section ("Knowledge Files" table or "Before Answering" routing rules)
- [ ] Has a judgment section ("Guiding Principles" or "How to Advise")
- [ ] Has a context section ("Domain Context", "Context", or "Background")
- [ ] Has an "Output" section
- [ ] Has a "Rules" section
- [ ] Has a "Bootstrapping" block (graded in depth — including severity — by the Operate-Mode Bootstrap check below)

Section names vary between template generations and hand-rolled agents — match by function, not exact heading. An adopted agent with equivalent prose sections passes.

**Severity:** Important if sections are missing.

### Tool List Consistency
- [ ] If the agent references skills (alek-voice, slack-cli, etc.) → `Skill` must be in the tools list
- [ ] If the agent dispatches sub-agents → `Agent` must be in the tools list
- [ ] If the agent uses MCP tools → those MCP tool prefixes should be mentioned in the tools list or Domain Context

**Severity:** Important — agent will fail to invoke skills/agents if tools aren't listed.

### Knowledge File References
- [ ] Every file referenced in the agent's routing rules/table actually exists on disk
- [ ] Every knowledge file in the agent's directory is referenced somewhere in the agent (no orphaned files)

**Severity:** Critical if referenced files are missing. Minor if files exist but aren't referenced.

### Domain Index Integrity
- [ ] The domain folder has an `index.md` inventory
- [ ] Diff disk vs. index: every file in the folder (including data exports, logs, code projects) appears in the index; every index entry exists on disk
- [ ] Hub CLAUDE.md does NOT carry a per-file inventory (per-file lists at the hub level always drift — they belong in domain indexes)

**Severity:** Minor if index missing at L2, Important at L3+. Orphan files (on disk, not indexed) → Important — unindexed knowledge is unreachable ("captured ≠ findable"). Dead index entries → Important.

#### Knowledge File Schema Validation (L2+)

For every `.md` file in the agent's directory that is NOT the agent skill file:

**Required frontmatter fields:**
- `domain` — must match the agent's domain slug
- `type` — must be one of: `reference`, `register`, `status`, `index`, `reference-library`
- `description` — non-empty string
- `decay` — must be one of: `fast`, `medium`, `slow`
- `confidence` — must be one of: `high`, `medium`, `low`
- `last_updated` — valid ISO date (YYYY-MM-DD)

**Optional fields (validated if present):**
- `review_by` — valid ISO date, must be after `last_updated`
- `sources` — array of objects, each with `path` or `url` key and `type` key

**Severity:**
- Missing frontmatter entirely → Important
- Missing required field → Important
- Invalid enum value → Important
- Missing `review_by` on `decay: fast` files → Minor

#### Size Budget Compliance

Check line count of each knowledge file against target budgets:

| File Type | Target | Minor threshold | Important threshold |
|---|---|---|---|
| Knowledge file | 200 lines | > 300 lines (1.5x) | > 400 lines (2x) |
| Agent skill file | 300 lines | > 450 lines (1.5x) | > 600 lines (2x) |
| Hub CLAUDE.md | 200 lines | > 300 lines (1.5x) | > 400 lines (2x) |

Severity as indicated. Message: "File exceeds size budget — likely growing beyond index-layer scope. Consider splitting or extracting content to vault."

#### Confidence Field Quality

- Missing `confidence` in frontmatter → flagged by schema validation above
- Files with `confidence: low` and no `review_by` date → Minor ("low-confidence file should have a review-by date indicating when verification is planned")
- Report confidence distribution per domain: count of high/medium/low files

### Reference Library (L3+)

For each agent directory, check:

- [ ] `reference-library.md` exists at the domain root
- [ ] It has a `## Scope` section (2-3 sentences) — without this, first-pass filtering can't work
- [ ] Every entry carries triggers — either the `Triggers` column of a `Topic | Source | Triggers` table row (the default format per `protocol/knowledge-schema.md`) or a `**Triggers:**` block field (escape hatch; legacy `**Retrieval triggers:**` counts but is flagged as legacy format)
- [ ] Every entry carries a source — the `Source` table column or a `**Source:**` block field — pointing to a reachable path or URL (`Install:`/`Fallback:` for skills/tools entries)
- [ ] The file is under the 200-line cap (`protocol/knowledge-schema.md` § Size) — the table format is the primary lever for staying under it
- [ ] Agent has the Reference Library Discovery Protocol section (or equivalent routing rule pointing to it)

For each subdirectory under the agent folder:
- [ ] If a `reference-library.md` exists in a subdirectory, confirm it also has a `## Scope` header (sub-libraries without scopes can't be filtered and will always be loaded in full — expensive)
- [ ] Entries in sub-library files that have no matching routing-rule entrypoint are still valid — discovery is convention-based

**Severity:**
- Missing `reference-library.md` entirely at domain root → Minor at L2, Important at L3+
- `## Scope` missing from any `reference-library.md` → Important (breaks first-pass filtering)
- Entry with no triggers (empty table cell or missing block field) → Minor ("document is indexed but the agent can't decide when to load it")
- Entry with no source → Important ("entry is unreachable")
- Library over 200 lines → Minor ("convert block entries to table rows before cutting coverage")
- Block-form entries used as the default (most entries block-form with no `**Note:**`-style routing context) → Minor ("convert to the table format")

### Wiki-Link Integrity (Obsidian vaults only)

Applies only to hubs stored in an Obsidian vault (bare `[[Name]]` links present). A standard resolve-check catches *dead* links; it does **not** catch *ambiguous* ones — and ambiguity fails silently. In Obsidian a bare `[[Name]]` resolves by basename, so when two files share a basename the link resolves to whichever one Obsidian picks, with no error anywhere.

- [ ] For every bare `[[Name]]` link, count basename matches vault-wide (`find . -name "Name.md" | wc -l`, excluding `.git`/`_archive`/worktrees). More than one match → the link is ambiguous.

**Severity:** Ambiguous bare link → Important even though nothing is "broken" — the link may already resolve to the wrong note. The fix is to path-qualify it (`[[folder/Name]]`), not to leave it bare. Structural per-domain files that are never bare-linked (each domain's `index.md`, `overview.md`) are expected duplicates and are not findings unless something actually bare-links them.

### Catalog Structure (L3+)

**Scope:** This check applies ONLY to knowledge files with `type: index` in frontmatter — document catalogs that point to external files (SharePoint, Confluence, vendor deliverables). It does NOT apply to `type: reference-library` files (routing indexes), `type: reference` files, or other knowledge files that happen to contain tables.

For each `type: index` knowledge file:

- [ ] Markdown tables containing document entries have `doc_type` and `authority` columns (see `references/document-quality.md`)
- [ ] `authority` values are in {`formal`, `baseline`, `delivered`, `working`} — flag org names, person names, or compound values
- [ ] Catalogs with vendor/external documents include a `source_org` column
- [ ] Catalog file size is under 500 lines — larger files degrade Ask routing efficiency

**Severity:**
- Missing `doc_type`/`authority` columns → Minor at L2, Important at L3+ ("catalog entries are uncategorized — agent can't prefer by authority")
- Non-standard `authority` value → Minor ("org names belong in source_org, not authority")
- Catalog over 500 lines → Minor ("consider splitting by domain or adding section anchors to reference-library entries")

### Hub Registration
- [ ] Agent is listed in the hub CLAUDE.md routing table
- [ ] The path in the routing table matches the actual file location

**Severity:** Important if unregistered (agent won't be discovered by routing).

### Operate-Mode Bootstrap

For every agent file registered in the hub's Agents table:

- [ ] The agent definition contains an **unconditional** bootstrap invoking the `second-brain` skill in **operate** mode as its first action — the `## Bootstrapping` block from `assets/agent-template.md`, or an equivalent instruction
- [ ] The instruction is not hedged. Flag phrasing like "consider invoking", "if relevant", "when appropriate" as a finding — skills activate at model discretion, so a hedge makes protocol loading optional, and an optionally-loaded protocol is an unenforced one
- [ ] `Skill` is in the agent's `tools:` list — without it the bootstrap cannot execute at all
- [ ] `auto_contribute` is explicitly declared in the agent's YAML frontmatter — the bootstrap resolves the contribution gate from this field, so it should be stated, not left to the implicit `false` default

**Severity:** Critical if the bootstrap is absent, or present but `Skill` is missing from `tools:` (equivalent to absent — it can never run). The agent has domain knowledge but never loads the learning loops, so its sessions don't compound; this is the single highest-value check in the audit. Hedged phrasing → Important (the protocol loads only when the model happens to judge it relevant). Undeclared `auto_contribute` → Minor (see Contribution Settings Health).

**Fix:** add the `## Bootstrapping` block from `assets/agent-template.md` (Step 1 of `references/migration.md`).

### Protocol Duplication in Local Files

The operating protocol — loops, Self-Awareness Protocol, triage, schema — lives only in the skill's `protocol/` files and reaches sessions via Operate mode. Any local restatement is a snapshot that drifts. Grep the hub `CLAUDE.md`, every domain `CLAUDE.md`, and each agent file for restated protocol content:

- Loop definitions (`Loop A` … `Loop E` with descriptions, not passing mentions)
- `## Self-Awareness Protocol` sections, or restated contribution-reflex / task-completion-gate text
- Triage category tables (`[correction]`, `[discovery]`, `[contradiction]` mappings)
- `auto_contribute` behavior rules restated at length (beyond declaring the setting or noting that frontmatter is authoritative)
- Knowledge-maintenance step lists (how-to-update-knowledge-files procedures that duplicate the protocol)

Also check for a `protocol/` folder at the hub root — or copies of `learning-loops.md` / `triage-policy.md` / `knowledge-schema.md` anywhere in the hub tree. Protocol files are served by the skill and are never copied into hubs.

Pointers are not restatements: the agent template's Bootstrapping block and the Rules no-restatement preamble *name* these concepts in order to point at the protocol layer — that is compliant. A finding is content that *defines* or *reproduces* them locally.

For each hit, compare against the current `protocol/` files and grade:

| Finding | Severity |
|---|---|
| Restatement **matches** the current protocol | Important — redundant and will drift; replace with the Operate-mode pointer |
| Restatement **lags** the protocol (e.g. four loops and no Loop E, no `auto_contribute` gate) | **Critical** — the hub is running a superseded protocol, and nothing else in the audit detects it. Report exactly what the restatement is missing. |
| Restatement **contradicts** the protocol | **Critical** — the protocol wins; the local file is actively misleading |

**Also flag:** bare relative `protocol/*.md` path references in local files when no such folder exists locally. Those paths resolve relative to the skill's base directory — inside a skill invocation they work; from the hub they point at nothing. A dead pointer masquerading as a citation → replace with the Operate-mode pointer.

**Fix:** `references/migration.md` walks the cleanup — bootstrap lands first, then strip.

### Rule Completeness
Check the agent's `## Rules` section against the standardized rules in `assets/agent-template.md`. Match by **function**, not by number — the template's rules are function-named and their order/count changes as the template evolves, so keying this check to numbers guarantees drift.

Always-applicable functions (flag any missing):
- **Bootstrap** — the unconditional `## Bootstrapping` block invoking Operate mode (a section of its own, not a numbered rule; graded in depth by the Operate-Mode Bootstrap check above)
- **Never fabricate** — no invented facts; state uncertainty explicitly
- **Cite sources** — file paths, URLs, document names for all claims
- **Prefer shared improvements** — document workarounds and note the upstream fix

Domain-conditional rules (flag as missing only when the domain warrants them, via the template's `{DOMAIN_HARD_RULES}` slot):
- **External-systems gate** — required if the agent can modify external systems (Monarch, Google, etc.)
- **Sensitive-data handling / disclaimers** — required for financial, medical, legal, or otherwise private domains
- **Human review** — required if any output is shared externally
- **Conservative on risk** — required for compliance/security domains

**Do NOT flag as missing:** temporal-annotation rules, supersede-don't-overwrite, the Contribution Gate, loop definitions, or a Self-Awareness Protocol section. Those functions moved to the protocol layer and load via Operate mode; the bootstrap is their replacement in the agent file. An agent that *restates* them is a finding under Protocol Duplication above, not a compliant one.

**Severity:** Low for missing rules that aren't relevant to the domain. Important for missing rules that are relevant (e.g., disclaimer rule missing in a medical/financial domain).

## Step 3: Knowledge Freshness Checks

For each knowledge file in each agent's directory:

### Temporal Annotation Coverage
- Scan for `[learned: YYYY-MM-DD]` tags
- Count: total facts (lines starting with `- ` or `| ` in tables) vs. annotated facts
- Calculate coverage percentage

**Scoring:**
- 80%+ annotated → Green
- 40-80% annotated → Yellow ("many facts lack timestamps")
- <40% annotated → Red ("most facts are untracked")

### Staleness Detection
- Check for the `<!-- decay: fast/medium/slow -->` comment at the top of each file
- If decay rate is set:
  - Fast: flag `[learned:]` dates older than 14 days
  - Medium: flag `[learned:]` dates older than 60 days
  - Slow: only flag if `[review-by:]` has passed
- If no decay rate set: use medium as default

- Check `[review-by: YYYY-MM-DD]` tags — flag any that have passed today's date as "overdue review"

### Unratified Agent Decisions

- Scan knowledge files for `[decided: <who>, YYYY-MM-DD]` annotations where `<who>` is an agent id (e.g. `claude`) — anything that is not a known human name from the hub's Shared Context — rather than a human
- An agent decision is **ratified** when a human `[decided:]` annotation appears on the same fact, accompanying or later (agent chose → human confirmed)
- Flag agent `[decided:]` markers with no such human `[decided:]` as "unratified agent decision — surface for human review", and list them in the report as ratification candidates per `protocol/knowledge-schema.md`

**Severity:** Minor by default; Important once the annotation is more than 30 days old — a fork an agent took autonomously should not sit unreviewed for a month.

### Git-Based Staleness
- Run `git log -1 --format="%ai" -- "{file_path}"` for each knowledge file
- Flag files not modified in 60+ days as "potentially stale (no git activity)"

**Severity:** Important for overdue reviews and fast-decay staleness. Minor for git-based staleness (the file might just be stable).

#### Mechanical Staleness (Sync Drift)

If `.staleness-manifest.json` exists at the hub root:

1. For each knowledge file with `sources:` in frontmatter, look up the entry in the manifest
2. Re-fingerprint each source:
   - `directory`: file count + newest mtime (via `ls -R`)
   - `file`: mtime + size (via `stat`)
   - `git-repo`: HEAD sha + last commit date (via `git log -1`)
   - MCP-backed sources (issue trackers, wikis, finance tools): use the relevant MCP's cheapest count/last-modified query for the source type listed in the hub's content-source catalog
3. Compare fingerprint to manifest. If source fingerprint changed but knowledge file's `last_updated` hasn't moved since manifest's `last_synced` → flag as **sync-stale**
4. Update manifest with new fingerprints and `last_checked` date

If `.staleness-manifest.json` does NOT exist:
1. Create it by fingerprinting all knowledge files with `sources:` arrays
2. Set `last_synced` = today for all entries (no false alerts on first run)
3. Report: "Staleness manifest seeded with N source entries. Run audit again to detect drift."

**Severity:** sync-stale = Important

**Graceful degradation:** If a source is unreachable (MCP down, VPN not connected, path not mounted), skip it and note in the report: "Source unreachable: {source}. Skipped fingerprinting."

## Step 3b: Learning Loop Health

The five reinforcement loops (A-E) are the system's compounding mechanism. This step checks whether they're working. For operational rules see `protocol/learning-loops.md`; for rationale and failure modes see `references/learning-loops.md`.

### Feedback Propagation (Loop A)

If the project uses a memory system (e.g., `memory/feedback_*.md` files):
1. Scan memory feedback files for domain-specific corrections
2. For each feedback file: check if `propagated_to:` frontmatter field exists
3. If missing AND content is domain-specific (mentions a specific agent, workflow, or knowledge file) → flag as "pending propagation"
4. For each flagged file, suggest a propagation target based on content analysis (which agent or workflow file should contain this rule?)

Report: "N feedback files pending propagation to agent rules" with file names and suggested targets.

**Severity:** Important — corrections that live only in memory can be compacted or missed. This is the most common way the system fails to improve. See "The Compaction Problem" in `references/learning-loops.md`.

### Workaround Documentation (Loop B)

Scan agent Domain Context sections and knowledge files for:
1. Content that reads like a workaround for a tool limitation rather than stable architectural knowledge — these should be in knowledge files with `[learned:]` tags and decay annotations rather than hardcoded in the agent definition
2. Workarounds in knowledge files that lack `[learned:]` annotations — these can't be staleness-tracked
3. Cross-domain workarounds that appear in a single agent's files but should be in hub Shared Context

**Severity:** Minor — informational. The goal is to surface workarounds so they can be properly tagged, tracked, and potentially fixed upstream.

### Custodian Currency (Loop C)

If a `custodian-workflow.md` exists at the hub:
- Check `_reports/` for the most recent `custodian-*.md` file
- If none: Minor ("custodian has never run")
- If last run > 14 days ago: Minor ("custodian hasn't run recently — consider scheduling as part of weekly report")
- If last run > 30 days ago: Important
- Check whether the custodian's check count has grown since creation (compare current step count against the template baseline). If unchanged after 60+ days of use: Minor ("custodian checklist hasn't grown — are manual corrections being fed back via Loop C?")

If no `custodian-workflow.md` exists:
- Minor at L3: "Consider adding a custodian workflow for automated health checks"
- Important at L4+: "Custodian workflow is expected at this maturity level"

### Contradiction Resolution (Loop D)

Scan all knowledge files for `[disputed: YYYY-MM-DD]` annotations:
1. For each `[disputed:]` entry, check if it has been resolved (superseded or confirmed)
2. Unresolved disputes older than 14 days → Important ("Unresolved contradiction in {file}: {old claim} vs {new claim}")
3. Count total disputed entries and check velocity: 2+ disputes of the same fact in 30 days → Critical ("Repeatedly disputed fact — needs authoritative resolution")
4. Check that agents bootstrap Operate mode with `Skill` in their tools list. Missing → flag as "Operate-mode bootstrap not configured in {agent}" (graded by the Operate-Mode Bootstrap check in Step 2)

Also scan for *silent contradictions* — cases where two knowledge files contain conflicting facts about the same entity (same person with different roles, same system with different status) without `[disputed:]` tags. These indicate Loop D hasn't been firing.

**Severity:** Important for unresolved disputes. Critical for high-velocity disputes.

### Process Retrospection (Loop E)

For each agent:
1. `git log --follow -5 -- {agent_file}` — when did the agent definition last change?
2. Compare against domain activity (knowledge file git activity in the same window)
3. Domain active 60+ days with zero agent-definition changes → Minor ("Loop E may not be firing — the agent file should evolve with use, or record an explicit reviewed-no-change")
4. Rules/Principles section over budget or containing rules with no observable purpose → Minor ("check eviction discipline — dead rules erode the file's authority")
5. If `_reports/loop-health.json` exists, check `process_revisions_proposed` is non-zero over 60+ days of active use (the protocol's mature-or-asleep heuristic)

### Golden-Question Eval Coverage (L4+)

- [ ] Each domain has a `golden-questions.md` (see `assets/golden-questions-template.md`)
- [ ] The run log shows a run within the last quarter
- [ ] Failures from the last run have propagation notes (each Fail became a Loop A/B fix)

**Severity:** Minor at L3 ("consider adding golden-question evals"), Important at L4+ ("no objective regression signal — can't distinguish compounding from decaying").

### Contribution Settings Health

Check each agent's frontmatter for `auto_contribute` setting:
- If missing → Minor ("No auto_contribute setting found in {agent} frontmatter — defaulting to false. Consider adding it.")
- If set to `true` but the agent lacks the Operate-mode bootstrap → Critical ("auto_contribute: true grants direct write access, but without the bootstrap the triage policy that bounds it never loads")
- If `_reports/loop-health.json` exists, review for patterns (stagnant custodian checks, high pending-to-propagated ratio)

## Step 4: Cross-Agent Consistency

### Stakeholder Conflicts
- Read all `stakeholders.md` files across agents
- Check for the same person listed with different roles in different agents
- Flag conflicts: "{person} is listed as {role_a} in {agent_a} but {role_b} in {agent_b}"

**Severity:** Minor (often legitimate — same person, different context).

### Delegation Integrity
- For each delegation rule ("delegate to {agent}"), verify the target agent exists
- For each delegation, check if the target agent has a corresponding "receives delegation from" awareness

**Severity:** Important if delegation target doesn't exist. Minor if target exists but lacks awareness.

### Duplicate Knowledge
- Check if the same fact appears in multiple agents' knowledge files
- Look for: identical URLs, identical people+role combinations, overlapping key dates

**Severity:** Minor — flag as "consider which agent should be authoritative for this fact".

## Step 5: Maturity Scoring

Read `references/maturity-model.md` and score each agent:

- Check each maturity requirement from the L1-L5 table
- Assign the highest level where ALL requirements are met
- Report per-agent: "Agent {name}: Level {L} — {level_name}"

## Step 6: Generate Report

Write the report to `{hub_dir}/_reports/audit-{YYYY-MM-DD}.md`:

```markdown
# Second Brain Audit — {YYYY-MM-DD}

## Summary
- **Hub:** {hub_path}
- **Agents audited:** {N}
- **Overall health:** {Green/Yellow/Red — worst agent score}

## Per-Agent Scores

| Agent | Maturity | Structural | Freshness | Overall |
|-------|----------|-----------|-----------|---------|
{one row per agent, with Green/Yellow/Red per category}

## Findings

### Critical
{numbered list of critical findings with file paths and suggested fixes}

### Important
{numbered list}

### Minor
{numbered list}

## Quick Wins
{top 3-5 lowest-effort fixes that would improve scores the most}

## Recommended Next Steps
1. {highest-impact action}
2. {second-highest}
3. {third}
```

#### Health Score Computation

Compute and include a quantitative health score in every audit report:

| Dimension | Weight | Scoring |
|---|---|---|
| Structural Completeness | 25% | % of per-agent audit checks passing |
| Annotation Coverage | 20% | % of non-heading, non-blank body lines with `[learned:]` tags (in status/register/reference files only — index and reference-library are pointers, not fact stores) |
| Freshness | 20% | 100 minus deductions per stale file (fast-stale = -10, medium-stale = -5, slow-stale = -2, sync-stale = -8) |
| Confidence Quality | 15% | Weighted avg across files: high=100, medium=60, low=20. Penalize -10 per `low` file without `review_by` |
| Size Compliance | 10% | % of files within 1.5x budget |
| Cross-Domain Integrity | 10% | Existing cross-agent checks (stakeholder conflicts, delegation integrity) — % passing |

**Overall = weighted sum, capped at 100.**

Append score to `_reports/health-trend.json`:
```json
{ "date": "YYYY-MM-DD", "overall": N, "structural": N, "annotation": N, "freshness": N, "confidence": N, "size": N, "integrity": N }
```

Show delta from baseline (first entry) and from previous run.

## Step 7: Offer Auto-Fix

For findings that have safe, mechanical fixes:

- Missing hub registration → offer to add the agent to the routing table
- Missing `Skill` in tools list → offer to add it
- Missing temporal annotations baseline → offer to add `[learned: {today}]` to all un-annotated facts

For each auto-fix:
1. Show the proposed change
2. Ask for user confirmation
3. Apply if approved

Do NOT auto-fix anything that requires judgment (missing rules, restructuring, scope changes).
