# Contributing to the Apiary

This file is referenced by [CLAUDE.md](CLAUDE.md), which auto-loads for any agent editing the Apiary plugin. Follow it exactly.

## The Rule

**Every change to the Apiary's mechanical operations must be verified against the three canonical user scenarios before the PR is opened.** Protocol-only prose changes (design-goals, ethical-guidelines, ways-of-working) are exempt.

Mechanical operations = anything in: `mode-operate.md`, `mode-create.md`, `mode-upgrade.md`, `custodian-workflow.md`, `child-skill-template.md`, `child-settings-template.json`, `hive.schema.json`, `hive.yml.template`, or the `SKILL.md` router.

## Verification: Three Scenarios

After making changes, verify these three scenarios work end-to-end. The audience is non-SWEs — every path must be self-healing with no manual git knowledge required.

### Scenario 1: First Install

A user installs a child Hive skill (e.g., `orbit-hive`), types `/orbit-hive` for the first time. No `~/.claude-hive/orbit/` exists on disk.

**Must verify:**
- [ ] Child stub's Identity block (slug + remote) is read by Apiary
- [ ] Hive Discovery does NOT block with "No Hive found" — child stub invocations skip cwd walk
- [ ] `mode-operate.md` Step 0 (clone-or-pull phase) clones the repo to `~/.claude-hive/{slug}/`
- [ ] `hive.yml` is readable after clone
- [ ] Steps 1–5 load identity, persona, protocol, and execute workflow
- [ ] If SSH key is misconfigured, the error is visible and actionable (not swallowed)

### Scenario 2: Returning User (Remote Ahead)

User opens `/orbit-hive` three days later. Clone exists but remote default branch is many commits ahead.

**Must verify:**
- [ ] Step 0's clone-or-pull phase pulls latest (shallow pull is acceptable for content access)
- [ ] Step 0's ff-sync phase syncs to remote default branch via ff-merge
- [ ] Knowledge files reflect the latest remote state
- [ ] If ff-merge fails, session HALTS with actionable error — never proceeds with stale data

### Scenario 3: Rogue Branch with Uncommitted Work

A previous agent session left the clone on a feature branch with uncommitted changes.

**Must verify:**
- [ ] Step 0's branch-normalize phase detects non-default branch
- [ ] Orphaned Branch Recovery commits uncommitted changes, pushes the branch, opens a draft PR tagging codeowners
- [ ] Clone switches to default branch after recovery
- [ ] Session proceeds normally on the default branch
- [ ] No work is silently lost (no `git stash` without push, no `git checkout --force`)

## How to Verify

### Option A: Run the test script (fast, local, no GHE dependency)

```bash
bash plugins/apiary/skills/apiary/tests/clone-flow.test.sh
```

This exercises the git-flow scenarios against a local bare repo. All tests must pass.

### Option B: SGCM scenario walkthrough (thorough, for protocol changes)

If your change modifies the mode-operate.md Step 0 git flow, the SKILL.md Mode Detection / Hive Discovery, or the child-skill-template.md invocation pattern:

1. Read the changed files
2. Trace each scenario step-by-step through the actual code
3. For each step, confirm: what triggers it, what the user sees, what happens on failure
4. Document the trace in the PR description

## Verification: Routing & Retrieval Golden Cases

**Every mechanical change must pass the three canonical scenario tests** (above) — that verifies
the git-flow mechanics. It says nothing about whether the *protocol prose* itself still routes and
retrieves correctly, because that prose is read and followed by an agent, not compiled. A confirmed
regression in PR #657 (`Prefer` reordered ahead of `Resolve` with no `authority` metadata to rank
on, and `Recurse` bypassing it entirely) shipped past the three scenarios and was caught only by a
human tracing the two-hop case by hand. The golden cases below exist to catch that class of defect
mechanically.

**Any PR touching `protocol/routing-protocol.md`, `protocol/knowledge-schema.md`,
`protocol/document-quality.md`, or `protocol/tool-tiers.md` must run these cases and report results
in the PR body.**

```bash
bash skills/apiary/tests/golden-routing.test.sh
```

This runs the deterministic half only — grep-able checks that the fixtures in
`skills/apiary/tests/golden/` are still shaped the way `skills/apiary/tests/golden/cases.md` says
they are. It does **not** verify agent behavior; the file's header explains why, and
`APIARY_GOLDEN_LLM_JUDGE=1` opts into the (non-deterministic, keyword-heuristic) behavioral half
against a live `claude -p` subagent. For a protocol change, run the behavioral half too and paste
the transcript summary — not just "cases pass" — into the PR body, since a fixture that still
parses correctly is not evidence the new prose routes correctly.

If a golden case reveals the protocol itself is wrong (not the test), **stop and report it** rather
than editing the case to match. That finding is worth more than a green run.

## Cross-Check Schema Changes Against Second Brain

Apiary and the [Second Brain](../second-brain) plugin share several knowledge-layer schemas — they evolved from the same design and are kept deliberately consistent (see the shared-taxonomy pointers in `protocol/document-quality.md`). **Any change to a shared schema here must be cross-checked against Second Brain to decide whether it applies there too.**

Shared surfaces to check on every schema change:

| Apiary file | Second Brain counterpart | What must stay consistent |
|---|---|---|
| `protocol/knowledge-schema.md` | `protocol/knowledge-schema.md` | Frontmatter fields, `type`/`decay`/`confidence` enums, inline annotations (`[learned:]`, `[decided:]`, `[disputed:]`, …), the reference-library entry format |
| `protocol/document-quality.md` | `references/document-quality.md` | `doc_type` and `authority` enums, `source_org`/`scope`/`supersedes` — the field definitions must be **identical** |
| `references/mode-audit.md` | `references/mode-audit.md` | Any validation/severity rule that enforces a shared schema (e.g. reference-library size cap, annotation coverage, catalog structure) |

**Rule:** When you touch any row above, open the counterpart file and decide explicitly: does this change apply there too? If yes, make it in the same PR (or a paired follow-up) and bump both plugins. If no, state why in the PR description — the two schemas may diverge intentionally (Apiary carries multi-writer governance — Parliament, CODEOWNERS, `extensions` — that a single-user Second Brain does not). "I didn't check" is not an acceptable answer; silent drift between the two is the failure mode this section exists to prevent.

## Other Requirements

- **Version bump required.** Bump `plugin.json` and `marketplace.json` per the repo-level [CONTRIBUTING.md](../../../../CONTRIBUTING.md).
- **Schema changes = major version bump.** New required fields in `hive.yml` are breaking. Add a migration to `mode-upgrade.md`.
- **Run the repo-level validation:** `python3 .circleci/validate_plugins.py`
- **Test against a real Hive if possible.** The widget-integration-hive-mind repo is the lightest-weight test target.
- **Routing/retrieval protocol changes** (routing-protocol, knowledge-schema, document-quality, tool-tiers) additionally require the golden cases — see § Verification: Routing & Retrieval Golden Cases above.

## Design Goals Compliance

**Before opening a PR that adds a new concept, directory, workflow, or content surface**, read `skills/apiary/protocol/design-goals.md` in full and verify compliance.

**Required in every protocol-changing PR description:**

For each goal, state whether your change satisfies, is neutral to, or could conflict with it. Focus on non-obvious interactions — don't write "neutral" 9 times. Call out:

- **Goal 1 (Reference, Don't Duplicate):** Does your change introduce a content surface that could drift from a source of truth?
- **Goal 2 (Progressive Discovery):** Are links/pointers descriptive enough for routing without loading the target?
- **Goal 4 (Collective Ownership):** Does your change bypass any quality gate? If so, what's the safety rationale?
- **Goal 5 (Contribution Flywheel):** Does your change add friction to the contribution path?
- **Goal 9 (Discoverability Guarantee):** If adding a new content surface — what is its index, which workflow maintains it, and how does Audit detect orphans?

**"I didn't check" is not acceptable.** A missing compliance section is a review blocker.
