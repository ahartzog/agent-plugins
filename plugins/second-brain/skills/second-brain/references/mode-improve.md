# Improve Mode — Agent Upgrade Workflow

This document guides the Improve mode of the `second-brain` skill. It analyzes a specific agent and proposes improvements based on gold-standard patterns.

**Before applying any fix, obey the [Safety Constraints](mode-audit.md#safety-constraints-hard-won--apply-to-every-audit-cleanup-or-fix) in `mode-audit.md`** — never delete, never edit inside code fences, don't touch escaped table pipes, no absence claims from sampled searches, split commits by author. This mode applies changes, so those constraints bind here most.

## Prerequisites

The SKILL.md has already run hub discovery. The user may have specified a target agent, or we need to ask.

## Step 1: Select Target Agent

If the user specified an agent (e.g., `/second-brain improve financial-advisor`):
- Find the agent by name in the hub routing table
- If not found, search for `*{name}*-agent.md` files

If no agent specified:
- List all agents from the hub with their current maturity levels (run a quick audit check)
- Ask: "Which agent would you like to improve?" — show the list with maturity scores
- Recommend the lowest-maturity agent or the one with the most findings

## Step 2: Deep Analysis

Read the target agent file and ALL its knowledge files. For each, analyze against the gold-standard template (`assets/agent-template.md`) and maturity model (`references/maturity-model.md`).

### Compare Against Template

For each template section, assess:
- **Present and complete?** Does the agent have this section with appropriate content?
- **Quality?** Is the content specific and actionable, or generic/placeholder?
- **Pattern alignment?** Does it follow the patterns from the gold standard?

### Identify Gaps

Categorize improvements by effort:

**Low effort (mechanical, safe to auto-apply):**
- **Install the operate bootstrap.** Copy the `## Bootstrapping — Required, Every Session` block from `assets/agent-template.md` into any agent missing it — and ensure `Skill` is in the tools list and `auto_contribute` is declared in the agent's own frontmatter. This is the highest-value single upgrade: without it the agent has domain knowledge but no enforced learning loops. Counterpart action, same edit — but **not** blindly mechanical: before **deleting** a local `## Self-Awareness Protocol` section or Contribution Gate restatement, scan it for embedded domain content (domain startup routines, domain-specific trigger examples, safety framings, graduation provenance) and relocate anything domain-specific to the agent's principles, context, or a session-start section — mature agents routinely grow domain judgment inside these sections. Then delete the restatement; a local protocol copy drifts, and the protocol loaded by operate mode is authoritative.
- Add missing YAML frontmatter fields
- Add `Skill` to tools list (if agent references skills)
- Add `<!-- decay: {rate} -->` comments to knowledge files
- Fix hub registration (add/update routing table entry)
- Create a domain `index.md` inventory (mechanical: list files with one-line descriptions + last_updated)
- Add frontmatter schema to knowledge files missing it (infer `type` from content structure — tables with paths → index, dates/deadlines → status, risk/decision tables and chronological logs → register, stable lookups → reference; infer `decay` from the schema's per-type defaults: status → fast, register/index → medium, reference/reference-library → slow; infer `confidence` → medium for cold-start)
- Add `sources:` array to knowledge files that contain obvious external pointers (OneDrive paths, Jira URLs, Confluence URLs) — extract from body content into frontmatter

**Medium effort (require user input on specifics):**
- **Migrate a hub or domain folder off restated protocol.** Read `references/migration.md` and follow it. In short: add the operate bootstrap to every agent first, then sort each `CLAUDE.md` section into universal-protocol (delete — it loads from the skill), agent-behavior (move to the agent's Rules), or genuinely-local (keep: routing, shared context, ambient guardrails, local knowledge policy). Rebuild a single-domain folder's `CLAUDE.md` from `assets/domain-claude-md-template.md`. Show the diff before applying — deleting local content is structural. Report explicitly what the old restatement was missing (e.g. "your copy restated four loops; the current protocol has five — you were running without Loop E process retrospection"). Ordering rule: the bootstrap lands before any stripping, and a partial migration stops after the bootstrap step — an agent with the bootstrap plus a redundant `CLAUDE.md` is safe; a stripped `CLAUDE.md` with no bootstrap is not.
- Add new "How to Advise" modes for question types the agent should handle but doesn't
- Add delegation rules to connect with other agents in the hub
- Create additional knowledge files (suggest which ones based on domain analysis)
- Add output format templates for different audiences
- Wire up new content sources (Jira boards, Slack channels, etc.)
- Add voice/style skill integration
- Set up golden-question evals: seed `golden-questions.md` from `assets/golden-questions-template.md` with questions mined from recent sessions (user supplies/confirms expected answers)
- Loop E review: walk the agent's Rules/Principles against recent sessions — propose revisions for rules that were worked around, principles missing worked examples, and procedures that should be principles
- Promote confidence: for each `confidence: medium` file, identify which source could verify it and suggest: "Verify {file} against {source} to upgrade confidence to high"
- Add inline `[confidence: low]` tags to specific entries the agent identifies as unverified claims (schedule dates from Slack, second-hand reports, estimated figures)

**High effort (require design collaboration):**
- Design and implement a repeatable workflow → redirect to `/second-brain add-workflow`
- Restructure knowledge files using three-tier memory taxonomy
- Build a collector-based data gathering pipeline
- Create an archive lifecycle for completed phases
- Set up custodian workflow → redirect to `/second-brain add-workflow` (custodian health pulse pattern)
- Add enforcement hooks (custodian nudge, retrospection reminder, raw-layer protection) → see `references/enforcement-hooks.md`; L4 feature, propose only when audit shows prompt-level discipline repeatedly failing
- Backfill feedback propagation: review all unpropagated `memory/feedback_*.md` files and propagate domain-specific corrections to agent rules (see "Loop A" in `references/learning-loops.md`)

## Step 3: Present Improvement Plan

Present improvements grouped by effort level. For each improvement:

```
### {Improvement Title}
**Effort:** Low / Medium / High
**Impact:** {what gets better — freshness, consistency, capability, automation}
**Current state:** {what the agent does today}
**Proposed change:** {specific description of the change}
**Maturity impact:** {which level this helps achieve}
```

Ask the user to approve/reject each category:
- "Apply all low-effort improvements automatically?"
- For each medium-effort improvement: "Would you like to add {X}? I'll need some input from you."
- For each high-effort improvement: "This requires more design work. Want to tackle it now or save it for later?"

## Step 4: Apply Approved Changes

### Low-Effort Changes
Apply these programmatically with Edit tool:

**Adding missing rules:**
- Read the agent's Rules section
- Compare against the template's domain rules (match by function — never-fabricate, citations, prefer-shared-improvements, external-systems gate)
- Append any missing rules, numbered sequentially
- Preserve existing rule numbers and content
- Remove any rule that restates the loaded protocol (contribution gate, temporal annotations, supersede-don't-overwrite, loop or triage summaries) — operate mode supplies those, and a local copy drifts

**Adding Skill to tools:**
- Edit the YAML frontmatter tools array
- Add `Skill` if not present

**Adding decay comments:**
- For each knowledge file without `<!-- decay: ... -->`:
  - Assess the content: mostly dates/statuses → fast; mostly decisions/architecture → medium; mostly organizational/foundational → slow
  - Add the comment on line 1

**Adding temporal baselines:**
- For each fact line (starting with `- ` or table row `| `) without `[learned:]`:
  - Append ` [learned: {today}]`
  - This is an approximation — the fact may be older, but it establishes tracking

### Medium-Effort Changes
For each approved medium-effort change:

1. Gather specifics from the user (which Slack channels? which Jira board? what voice skill?)
2. Generate the new content (routing rule, knowledge file, output template)
3. Show the proposed edit to the user
4. Apply if approved

### High-Effort Changes
Redirect to the appropriate mode:
- Workflow design → `/second-brain add-workflow`
- Knowledge restructuring → walk through the three-tier taxonomy interactively
- Collector pipeline → this is a substantial design exercise, suggest a dedicated session

## Step 5: Verify

After applying changes:

1. Run a targeted audit on just the improved agent (use the checks from mode-audit.md)
2. Show before/after maturity scores
3. Report: "Upgraded {agent_name} from L{before} to L{after}. {N} improvements applied."

If any audit checks still fail:
- Show remaining findings
- Suggest next steps

## Cold-Start: Improving a Non-Template Agent

If the agent file doesn't follow the template at all (no YAML frontmatter, no standard sections):

1. Don't try to patch it — and don't default to rebuilding. **Recommend `/second-brain adopt` first**: hand-rolled agents with accumulated judgment should be adopted (infrastructure added, voice preserved), not template-washed. Offer a rebuild only if the agent is genuinely unstructured AND the user prefers it:
2. If the user explicitly chooses rebuild:
   - Extract the domain knowledge from the existing file
   - Run through a condensed Create interview (pre-fill answers from existing content)
   - Generate a new agent file from the template
   - Keep the old file as `{name}-agent.old.md` for reference
3. If the user declines:
   - Apply whatever mechanical improvements are possible (rules, temporal annotations)
   - Note the limitations in the audit report
