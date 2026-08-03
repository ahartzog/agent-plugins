# Migrating an Existing Second Brain

For hubs and domain folders created before the protocol layer was single-sourced (skill v2.0.0). Run `/second-brain improve` to apply this automatically, or follow it by hand.

**Scope:** this migrates *previously-managed* hubs — ones this skill created or already adopted. For hand-rolled agents that were never under management, use `/second-brain adopt` (`references/mode-adopt.md`) instead; adopt installs the same bootstrap while preserving the agent's voice. The two cross-reference; they don't overlap.

**What changed and why:** the learning loops, contribution triage, and knowledge schema are universal — identical for every Second Brain. They used to be *copied* into each hub (a `protocol/` folder at the hub root) and *restated* into each agent file (a `## Self-Awareness Protocol` section, a Contribution Gate rule) at creation time, and those copies froze on the day they were written. Hubs created against older releases kept running a superseded protocol while looking perfectly healthy. They now load from the skill instead — updating the protocol updates every hub.

**The second shift:** behavioral rules move from `CLAUDE.md` into the **agent definition**. `CLAUDE.md` reliably loads only when a session's working directory is the hub — when an agent is invoked by file path, slash command, or skill shim from elsewhere, hub rules arrive late or not at all (lazy attachment on first file read is real but incidental — never something enforcement may depend on). The agent definition is read by definition, since reading it *is* invocation. Enforcement belongs where it cannot be missed.

## Diagnosis

Run `/second-brain audit`. It reports the migration gaps directly:

- **Missing operate bootstrap** (Critical) — the agent has no `## Bootstrapping` block, so it runs with domain knowledge but no enforced loops. Its sessions don't compound.
- **Protocol duplication in local files** — graded by whether the restated copy matches the current protocol, lags it, or contradicts it.

Or check by hand (agent files are whatever the hub's Agents table registers — check each listed path):

```bash
# Agents missing the bootstrap (run against each agent file in the hub table)
grep -L "second-brain.*operate" {agent-file...}

# Hub and domain files restating the protocol
grep -ln "Loop A\|Loop B\|auto_contribute" CLAUDE.md */CLAUDE.md

# Copied protocol folders at the hub root
ls protocol/ 2>/dev/null

# The lag tell: loop count dates the copy
grep -c "Loop D" CLAUDE.md   # 3-loop hub predates contradiction detection
grep -c "Loop E" CLAUDE.md   # 4-loop hub predates process retrospection
```

A hub restating only Loops A-C has been missing contradiction detection; one restating A-D has been missing Loop E — the loop that notices an agent's own rules going stale.

## Step 1: Add the Bootstrap to Each Agent

Highest-value change; do this first. Copy the `## Bootstrapping` block from `assets/agent-template.md` into each agent definition, immediately after the prime-directive paragraph and **before** the routing rules.

Then confirm, per agent:
- `Skill` is in the `tools:` list — without it the agent cannot invoke operate mode
- `auto_contribute` is declared in frontmatter (explicitly, even if `false`)

Keep the instruction unconditional. Hedged phrasing ("consider invoking", "if relevant") makes protocol loading discretionary, which defeats the purpose.

## Step 2: Move Behavior Out of CLAUDE.md

For each `CLAUDE.md` — hub and domain — sort every section into one of three buckets:

| Bucket | Destination | Examples |
|---|---|---|
| **Universal protocol** | Delete. It loads from the skill. | Loop definitions, Self-Awareness Protocol phases, triage tables, knowledge-schema field lists, `auto_contribute` behavior rules, knowledge-maintenance how-to steps |
| **Agent behavior** | Move to the agent definition's `## Rules` or `## Guiding Principles` | Domain writing conventions, citation requirements, output discipline, review gates |
| **Genuinely local** | Keep | Agent routing table, shared context, sensitivity/classification conventions, write-zone ownership, size budgets, index/archive conventions, folder orientation |

The test for the middle bucket: *would this rule matter to a session that never loaded an agent?* If no, it's agent behavior — move it. If yes (a privacy or filename convention applies even when hand-editing), it's an ambient guardrail and stays.

Replace deleted protocol sections with the pointer from `assets/hub-template.md` → "Operating Protocol — Loaded, Not Restated". For a domain folder, build from `assets/domain-claude-md-template.md` — a signpost to the agent file plus a short guardrail list. If the hub root carries a copied `protocol/` folder, delete it once every agent has the bootstrap — the skill's copy is the only live one.

**Report what the old copy was missing.** Don't migrate silently — tell the user, e.g. "your hub restated 4 loops; the current protocol has 5, so you were running without Loop E process retrospection." That's the whole reason this migration exists, and it's a Loop C signal worth naming.

## Step 3: Strip Duplicated Rules From Agent Files

Agents generated against older templates carry a `## Self-Awareness Protocol` section and a Contribution Gate rule restating the full contribution model. **Scan before deleting:** mature agents routinely grow domain content inside these sections — domain startup routines (data syncs, inbox checks), domain-specific trigger examples, safety framings, graduation provenance. Relocate anything domain-specific to the agent's principles, context, or a dedicated session-start section. **Then delete both sections.** The protocol now lives in `protocol/learning-loops.md` and is loaded, not copied. Its generic session-start warm-up scan is gone entirely — freshness inventory moved to `/second-brain audit`, so don't carry that step forward (domain startup routines are not warm-up; they stay, relocated).

Keep only domain rules in the agent's `## Rules` — the universal ones (temporal annotations, supersede-don't-overwrite, frontmatter requirements, contribution gating) come from the protocol. Match rules by function, not number: if a workflow file cites "Rule 6" of a file being trimmed, repoint it to the rule's function or to the protocol.

Do not leave a "fallback summary." A local copy drifts, and a drifted copy is worse than none.

## Step 4: Verify

```bash
/second-brain audit
```

Expected: no Critical findings for missing bootstrap or protocol duplication. Then invoke one agent and confirm it reports loading the protocol (`Protocol loaded: 5 loops, auto_contribute=…`) as its first action.

**Behavioral check:** invoke an agent from a directory *outside* the hub — by file path, skill shim, or slash command. Pre-migration, rule delivery depended on the session's working directory and incidental lazy loading. Post-migration the agent bootstraps the protocol regardless of where the session started. That difference is the point of the migration.

## The Skill Is a Prerequisite

Every maintainer of a Second Brain needs the `second-brain` skill installed — the hub or domain `CLAUDE.md` Dependencies section carries the install pointer (for this marketplace: `claude plugin install second-brain@ahartzog`).

There is no fallback protocol, by design. The loops and schema exist only in the skill, so an agent without it has no operating protocol — not a reduced one, none. It answers questions from knowledge files and reports findings as plain text, but does not write. That is deliberate: visibly degraded beats invisibly broken, and it beats a drifting local copy.

**This applies to externally-shared folders too** — a domain folder synced to a collaborator or split into its own repo. Make the skill a stated prerequisite in the folder's `CLAUDE.md` Dependencies section rather than shipping a restatement of the protocol alongside it. One fewer copy to rot.

## Order Matters

Step 1 before steps 2-3. Stripping protocol out of `CLAUDE.md` and agent files before agents can load it from the skill leaves a window where the rules are in neither place. If you migrate only partway, stop after step 1 — an agent with the bootstrap and a redundant `CLAUDE.md` is safe; a stripped `CLAUDE.md` with no bootstrap is not. The same holds for skill *versions*: don't strip local copies until the installed skill actually serves operate mode (v2.0.0+).
