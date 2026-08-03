# Second Brain Maturity Model

Use this to assess where an agent sits today and what concrete steps level it up. The audit mode references these levels when scoring agents.

## Levels

### L1 — Basic

**What it looks like:**
- Single agent file with basic instructions
- 1-2 knowledge files (maybe just an overview)
- No temporal annotations on facts
- No workflows or repeatable operations
- No hub CLAUDE.md (agent stands alone)
- Questions answered from the agent's general training, not domain-specific knowledge

**How to get here:**
- Run `/second-brain create` and complete the basic interview

**Value:** Better than nothing. The agent at least knows its domain scope and where to look for information.

---

### L2 — Structured

**What it looks like:**
- Agent follows the gold-standard template (all 6 sections present)
- 3+ knowledge files with clear semantic separation (overview, stakeholders, at minimum)
- Temporal annotations (`[learned:]`) on key facts
- Hub CLAUDE.md exists with agent routing table
- "Before Answering" section has numbered routing rules pointing to specific knowledge files
- Output format templates defined for common question types

**How to get here from L1:**
- Run `/second-brain improve` on the agent
- Add temporal annotations to existing facts
- Create a hub CLAUDE.md if one doesn't exist
- Add at least one more knowledge file (stakeholders.md is usually the most valuable)
- All knowledge files have valid YAML frontmatter with required fields (domain, type, description, decay, confidence, last_updated)

**Value:** Sessions start fast because the agent loads relevant context before answering. Knowledge persists across sessions.

---

### L3 — Connected

**What it looks like:**
- Agent delegates to and/or receives delegation from other agents
- `reference-library.md` exists with a `## Scope` header and at least one entry carrying triggers (a `Topic | Source | Triggers` table row — the default format — or a `**Triggers:**` block). Contributors in subdirectories can add their own sub-library; the agent discovers all of them automatically via the Discovery Protocol in the agent template.
- Multiple content sources wired up (Jira, Confluence, Slack, repos — not just filesystem)
- At least one repeatable workflow defined (status report, RFC template, scanning runbook)
- Knowledge files reference external sources by URL/path rather than duplicating content
- Agent uses the `Skill` tool to invoke other skills (voice, slack-cli, outlook, etc.)
- Agent bootstraps Operate mode: unconditional `## Bootstrapping — Required, Every Session` block, `Skill` in the tools list, `auto_contribute` declared in the agent's own frontmatter — see `references/mode-operate.md`
- Hub has the "Operating Protocol — Loaded, Not Restated" pointer section and the contribution-settings note (agent frontmatter is authoritative)
- The second-brain skill is installed where the agent runs; the Operate bootstrap loads `protocol/` files from the skill — never copied into the hub

**How to get here from L2:**
- Wire up content sources: install relevant MCP plugins, add source routing to agent
- Define at least one workflow using `/second-brain add-workflow`
- If other agents exist in the hub, add delegation rules ("If asked about X, delegate to Y")
- Add `Skill` to the tools list and reference relevant skills
- Key knowledge files (those indexing external resources) have `sources:` arrays in frontmatter for mechanical staleness tracking
- Add the unconditional Bootstrapping block (`Skill(second-brain)` with "operate" as the agent's first action), ensure `Skill` is in the tools list, and declare `auto_contribute` in the agent's frontmatter — verify the second-brain skill is installed first (`claude plugin install second-brain@ahartzog`); for previously-managed hubs, follow `references/migration.md`

**Value:** The agent is now a genuine operational tool, not just a Q&A assistant. It can pull live data, produce structured outputs, and has the infrastructure for self-improvement.

---

### L4 — Disciplined

**What it looks like:**
- Task-completion gate honored in practice (knowledge file updates after every session) — enforced by the protocol loaded via the Operate bootstrap, not restated in the hub
- Audit passes clean: no missing files, no stale knowledge, no structural inconsistencies
- Knowledge freshness actively tracked via `[learned:]` and `[review-by:]` annotations
- Decay classification set per knowledge file (`<!-- decay: fast -->`)
- Human review rule enforced for external-facing outputs
- Upstream-learning directive in rules ("prefer improving shared skills over local workarounds")
- **Learning loops actively working:** feedback propagation rate is Green (100%), custodian runs regularly, workarounds are documented in knowledge files with annotations — not just memory
- **Loop D active:** contradictions flagged with `[disputed:]` and resolved within 14 days
- **Loop E active:** agent definitions evolving with use — process revisions proposed and applied, dead rules evicted; golden-question evals exist per domain and have run at least once
- Custodian workflow exists and runs at least every 14 days (manually or via weekly report integration)
- `_reports/loop-health.json` exists and is being appended by custodian runs

**How to get here from L3:**
- Run `/second-brain audit` and fix all findings
- Add `[review-by:]` dates to fast-decay facts
- Add decay classification comments to all knowledge files
- Ensure the hub CLAUDE.md has the local knowledge policy (size budgets, archive rules, what-not-to-update)
- `.staleness-manifest.json` exists at hub root and most recent audit shows zero sync-stale findings. All `confidence: low` entries have an associated `review_by` date indicating when verification is planned.
- **Backfill Loop A:** propagate all domain-specific feedback files to their target agent rules. Zero unpropagated feedback files.
- **Activate Loop C:** set up custodian workflow and integrate into weekly report (Step 7.5 pattern)
- **Verify Loop B:** confirm workarounds are in knowledge files, not just memory. Audit Step 3b should show Green.

**Value:** The system is self-maintaining AND self-improving. Knowledge stays fresh because staleness is detected. Corrections persist because they're in agent rules. The custodian grows smarter because manual catches feed back into its checklist.

---

### L5 — Evolving

**What it looks like:**
- Contributing improvements upstream: shared skills, MCP servers, or connector improvements
- Collector-based automation pipelines for recurring data gathering
- Archive lifecycle for completed program phases (`_Archive/` convention)
- Episodic memory actively maintained (lessons-learned.md, decisions.md)
- Multiple workflow patterns in use (not just one)
- The agent ecosystem is self-reinforcing: improvements to one agent benefit others
- **Custodian checklist has grown** since initial creation — evidence that Loop C is compounding
- **Loop B discoveries have driven upstream improvements** — at least one shared skill or MCP server improved based on a workaround discovery
- **Triage policy has evolved** — Loop C data has driven at least one category reclassification (prompt→auto or vice versa)

**How to get here from L4:**
- Identify a Yellow/Red source in the content catalog → build or improve a shared connector
- Implement a collector pipeline for automated data gathering
- Add episodic knowledge files (decisions.md, lessons-learned.md)
- Archive completed work phases rather than letting them clutter active knowledge
- Share your workflow patterns with other teams
- Verify custodian checklist growth: compare current check count against the initial template

**Value:** Full flywheel in motion. The system continuously improves itself, contributes to the broader ecosystem, and handles operational complexity that would be impractical manually. The five loops are visibly compounding: corrections don't recur, workarounds are documented and sometimes fixed upstream, contradictions are caught and resolved, the custodian catches issues that used to require manual attention, and agent definitions evolve instead of accumulating dead rules.

## Using This in Audits

The audit mode maps each check to a maturity level:

| Check | Required for Level |
|-------|-------------------|
| Agent file exists with valid YAML | L1 |
| Follows template structure (all 6 sections) | L2 |
| 3+ knowledge files | L2 |
| Temporal annotations present | L2 |
| Hub CLAUDE.md with routing | L2 |
| Content sources wired up | L3 |
| At least one workflow defined | L3 |
| Agent delegates to/from others | L3 |
| `reference-library.md` exists with Scope + at least one triggered entry | L3 |
| Knowledge files have valid frontmatter schema | L2 |
| `sources:` arrays populated for key knowledge files | L3 |
| Bootstraps Operate mode: unconditional Bootstrapping block, `Skill` in tools, `auto_contribute` declared in frontmatter | L3 |
| Hub has "Operating Protocol — Loaded, Not Restated" pointer + contribution-settings note | L3 |
| second-brain skill installed; protocol loaded via Operate bootstrap (no per-hub `protocol/` copies) | L3 |
| Task-completion gate honored (via Operate bootstrap, not hub restatement) | L4 |
| No stale knowledge (audit clean) | L4 |
| Decay classification set | L4 |
| `.staleness-manifest.json` exists, zero sync-stale findings | L4 |
| No `confidence: low` entries without a verification plan (`review_by`) | L4 |
| Loop A: 100% feedback propagation rate | L4 |
| Loop B: Workarounds in knowledge files, not just memory | L4 |
| Loop C: Custodian exists and runs regularly (≤14 days) | L4 |
| Loop D: Contradictions flagged and resolved within 14 days | L4 |
| Loop E: Agent definitions revised with use (or explicit reviewed-no-change), dead rules evicted | L4 |
| Golden-question evals exist per domain, run at least quarterly | L4 |
| Domain `index.md` inventories exist and match disk | L3 |
| `_reports/loop-health.json` exists and tracking | L4 |
| Upstream contributions | L5 |
| Collector pipeline | L5 |
| Archive lifecycle | L5 |
| Custodian checklist has grown since creation (Loop C compounding) | L5 |
| Upstream improvements from Loop B discoveries | L5 |
| Triage policy evolved via Loop C data | L5 |
