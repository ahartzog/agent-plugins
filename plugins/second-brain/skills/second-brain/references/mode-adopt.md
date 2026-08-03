# Adopt Mode — Bring Existing Agents Under Management

This document guides the Adopt mode of the `second-brain` skill. It takes a hub of **hand-rolled agents** — agents written before this skill existed, or written by hand without it — and brings them under skill management **without rewriting them**.

**Scope:** adopt is for agents that were **never** under this skill's management. For hubs this skill created or previously adopted — ones carrying a copied `protocol/` folder, a restated `## Self-Awareness Protocol` section, or template-era Contribution Gate rules — use `references/migration.md` instead; it upgrades previously-managed structure to the single-sourced protocol. The two cross-reference; they don't overlap.

## Why This Mode Exists

Create mode assumes greenfield. Audit and Improve modes assume skill-generated structure. But the most valuable Second Brains are often hand-rolled: they predate the skill, they've absorbed months of corrections, and their voice and judgment frames are better than anything a template interview produces. Rebuilding them from the template would *destroy* accumulated value.

Adopt mode's contract: **preserve the agent's voice, principles, and accumulated judgment; add only the loop infrastructure it's missing.** The diff should read like an upgrade, not a replacement.

## Step 1: Inventory

1. Run hub discovery (already done by SKILL.md). Read the hub CLAUDE.md.
2. Extract the agent routing table. For each agent, read the agent file fully.
3. Also Glob for agent-shaped files NOT in the routing table (`*-agent.md`, `*advisor*.md`, files with `tools:` + `model:` frontmatter) — unregistered agents.
4. For each agent, build an adoption scorecard:

| Check | Present? |
|---|---|
| YAML frontmatter (name, description, tools, model) | |
| `auto_contribute:` frontmatter setting | |
| Guiding principles / judgment section | |
| Knowledge file routing (table or rules) | |
| Operate bootstrap present (unconditional `## Bootstrapping` block, `Skill` in `tools:`, `auto_contribute` declared) | |
| Temporal annotation discipline (`[learned:]` usage in its knowledge files) | |
| Knowledge files with schema frontmatter (type/decay/confidence) | |
| Referenced files exist on disk | |

5. Check the hub itself: "Operating Protocol — Loaded, Not Restated" pointer section? Contribution Settings note? Custodian workflow? `_reports/` dir? Also check for **legacy artifacts**: a `protocol/` copy at the hub root, or hub/agent sections restating loops or the Self-Awareness Protocol — those mean the hub was previously managed, so it's `references/migration.md` territory, not adopt.

Present the inventory as a table: agent × missing infrastructure. **Do not present prose criticism of the agents' content** — adopt mode evaluates infrastructure, not judgment. A hand-rolled agent with great principles and no annotations scores "missing annotations," not "needs rewrite."

## Step 2: Classify Each Gap

For each missing item, classify:

- **Additive** — can be added without touching existing content (e.g., install the Bootstrapping block, add `auto_contribute: false` to frontmatter, create `_reports/`). Safe.
- **Harmonizing** — existing content does the same job in different words (e.g., the agent has an "Update this file per Process Maintenance" rule covering ground the protocol's contribution gate now handles). **Default: keep the agent's wording, add only what's genuinely missing, and record the local convention in the hub.** Do not normalize working prose to match the template.
- **Conflicting** — existing content contradicts loop discipline (e.g., a rule that says "never write to knowledge files"). Surface to the user; never auto-resolve.

## Step 3: Propose the Adoption Plan

Present a per-agent plan, grouped by gap classification, with the exact text to be added. Honor existing style:

- If the agent uses prose principles, write the additions as prose principles — not numbered template rules.
- If the hub already has maintenance mandates (e.g., "Knowledge Maintenance (Mandatory)"), do not wire loop terminology into them or add a parallel section — the loops load from the skill via each agent's bootstrap. Keep what's genuinely local (size budgets, archive rules, write-zone ownership) in the hub's local knowledge policy; point the rest at the "Operating Protocol — Loaded, Not Restated" section from `assets/hub-template.md`. One pointer, not two mandates.
- Keep additions minimal: the Bootstrapping block is the only large block an adopted agent needs. Everything else is frontmatter fields and annotations. Do not add a Contribution Gate rule or restate loop/triage content into the agent — the operate bootstrap loads all of it.

Ask for approval per agent (or "apply all").

## Step 4: Apply

1. **Frontmatter:** add `auto_contribute: false` (or `true` if the user opts in — mature hand-rolled agents with months of correction history are often ready for `true` immediately; say so).
2. **Agent body:** install the `## Bootstrapping — Required, Every Session` block from `assets/agent-template.md`, placed immediately after the agent's opening/prime-directive paragraph. Adapt to the agent's voice **only** in the surrounding transition sentences — the `<CRITICAL>` block content stays verbatim, with its placeholders (`{AUTO_CONTRIBUTE}`, `{SKILL_INSTALL_POINTER}`) filled. Keep it unconditional. Confirm `Skill` is in the agent's `tools:` list and `auto_contribute` is declared in frontmatter — without those, the bootstrap can't run and operate mode can't resolve the gate.
3. **Hub:** the protocol loads from the skill — do not copy `protocol/` files into the hub. Add/merge the "Operating Protocol — Loaded, Not Restated" pointer section and the Contribution Settings note (frontmatter is authoritative) from `assets/hub-template.md`; no Learning Loops section, no Loop E mandate. If the hub already carries a `protocol/` copy from an earlier era, handle it per `references/migration.md` — delete it only after every registered agent has the bootstrap.
4. **Knowledge files:** do NOT bulk-annotate on adoption. The annotation rules arrive with the protocol via each agent's bootstrap — no restatement needed — so *new* facts get `[learned:]` tags from the next session on. Offer optional baseline annotation (`[learned: {today}]` on existing facts) as a follow-up — it's an approximation and the user should opt in. Add schema frontmatter (type/decay/confidence) to knowledge files, inferring values from content (status-like → fast decay; profiles/registers → medium; structural → slow).
5. **Memory backfill (Loop A):** if the project has `memory/feedback_*.md` files, scan for domain-specific corrections lacking `propagated_to:`. List them with suggested propagation targets. This is usually the highest-value single action in an adoption — months of corrections are typically sitting unpropagated.
6. **Registration:** ensure every agent is in the hub routing table and (optionally) registered as a skill/command per Create mode Step 3e.

## Step 5: Verify & Hand Off

1. Re-run the adoption scorecard — all gaps should now read Present or Deferred-by-user.
2. Run a light audit (mode-audit.md Steps 2-3b) on one agent to confirm nothing broke.
3. Report maturity levels before/after.
4. Suggest next steps: run the custodian for the first time, schedule it, consider golden-question evals (`references/workflow-patterns.md`), consider `auto_contribute: true` for the most-trusted agent.

## Anti-Patterns

- **Template-washing:** rewriting a working agent to match `assets/agent-template.md` section-for-section. The template is a floor for new agents, not a target for adopted ones.
- **Bulk retroactive annotation without consent:** `[learned:]` dates that lie about provenance are worse than no dates.
- **Duplicate mandates:** a hub with both a hand-rolled "Knowledge Maintenance" section and a pasted "Learning Loops" section saying the same thing in different words. Don't merge them into one restatement — the loops load from the skill. Replace both with the "Operating Protocol — Loaded, Not Restated" pointer, keeping only the genuinely-local policy.
- **Adopting without the memory backfill:** the unpropagated-corrections scan is the point of adopting — don't skip Step 4.5.
