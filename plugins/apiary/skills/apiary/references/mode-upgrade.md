# Upgrade Mode — Schema Migration

This document guides the Upgrade mode of the Apiary skill.

## Prime Directive

The Apiary exists to increase value to users through self-improvement and reduction of usage friction. Upstream improvements are always assumed good. Upgrades should be invisible, not a burden.

## When This Runs

- **Automatically**: When `operate` mode detects `hive.yml.upstream_version` has a major version behind the Apiary's current version
- **Manually**: When user invokes `/apiary upgrade`

Protocol improvements are delivered instantly through the installed Apiary plugin — no sync or vendoring needed. This mode handles breaking changes (major version bumps) that require schema migration.

## What Constitutes a Breaking Change (major version bump)

1. New required field in `hive.yml` schema
2. Renamed extension point in `hive.yml`
3. Changed `_custodian/config.yml` schema (new required key)
4. Structural change to child repo layout (new required directory)

## Process

### Step 1: Version Comparison

Read `hive.yml.upstream_version`. Compare against Apiary's current version.

- Patch/minor difference: No action needed. Protocol improvements are already live.
- Major difference: Proceed to Step 2.

### Step 2: Apply Migrations

For each major version jump, apply migrations in order:

Migration format (defined inline in this file, updated as versions ship):

```
## Migration: 1.x → 2.0

### hive.yml changes
- Added field `new_field` with default value `X`

### config.yml changes
- (none)

### Structural changes
- (none)

### Auto-apply
1. Add `new_field: X` to hive.yml if missing

### Requires human input
- (none)
```

Apply all auto-apply steps. Flag any "requires human input" steps with a brief summary and ask the user.

### Step 3: Bump Version

Update `hive.yml.upstream_version` to the Apiary's current version.

### Step 4: Resume

If upgrade was triggered automatically by `operate`, resume the original workflow. If triggered manually, show summary of what changed and confirm completion.

## Version Notes (non-breaking)

Minor/patch changes require no migration — they ship live through the installed plugin. This log
records what changed so operators reading `/apiary upgrade` output have an anchor.

### 2.24.0 — Ask quality: restatement, routing trace, `sources/` read path, bi-temporal validity

No `hive.yml` change and no required field — every item below is additive or a fix, and a Hive that
does nothing still gets the Step 0 and `sources/` repairs automatically. **One optional action is
worth taking**, called out first.

- **Action (one router row): make deposited sources reachable.** `sources/` was addressable but
  unreachable from a question. The RLDP §Resolve now carries a **Hive-root locator row** — a
  `sources/…` token resolves from the Hive root instead of `knowledge/` — which repairs the read
  path, but only for Hives that actually carry the router row `protocol/sources-policy.md`
  § Reference-Library Pointer prescribes:

  ```
  | Deposited sources | `sources/index.md` | meeting transcript, what did we decide, who said, exact wording, verbatim |
  ```

  Add it to any `knowledge/**/reference-library.md` if your Hive deposits sources. Audit's Source
  Index Integrity check now flags its absence (`WARN: source manifest exists but no
  reference-library entry points at it`), so `/apiary audit` will tell you whether you need it.
  If your Hive has no `sources/` content, nothing to do.

  *Why this was broken:* the prescribed row is written `sources/index.md`, and the old §Resolve rule
  resolved every local token against `knowledge/` — so it became `knowledge/sources/index.md`, which
  exists in no Hive. Audit Step 1b applied the same rule and independently reported the row as a
  broken pointer. Both sides are fixed; Step 1b now resolves a `sources/`-prefixed token from the
  Hive root, matching the read path exactly.

- **§Extract falls through to the verbatim original when the wording *is* the answer.** Exact
  values, requirement text, quotes, who-said-what: a curated `knowledge/` paraphrase is no longer
  quoted as if it were the source. Where a source and a knowledge file disagree, the source wins
  and the divergence becomes a `[correction]` contribution.

- **§Match restates the query before scanning triggers.** 2–4 alternate phrasings (synonyms,
  document vocabulary, entity names) on one line, scanned alongside the raw question. Triggers are
  written in the author's vocabulary and questions arrive in the asker's; this was the protocol's
  weakest step and it failed silently. Explicitly bounded: restatement, **not** decomposition or
  HyDE.

- **§Answer closes with a one-line routing trace**, and every citation must name a locator in its
  `opened:` list. This is the cheapest citation check available — an answer citing a document it
  never opened is now mechanically detectable — and it makes the answered-from-opened ratio
  available to Loop B. Deliberately one line: it runs on every Ask.

- **§Answer warns on a past-due cited file** — *per `x.md` (unverified since 2026-03-04)* —
  attached to the citation rather than as a separate caveat, so the warning travels with the fact.

- **New optional inline annotation `[effective: YYYY-MM-DD]`** — when a fact became true *in the
  world*, as distinct from `[learned:]` (when it entered the Hive). §Prefer ranks status questions
  on it when present; audit Step 2 decays individual facts from it when present. Both fall back to
  the existing clock when absent, so adoption is gradual and per-fact and no file becomes invalid.
  Mirrored into the Second Brain schema under the shared-taxonomy contract.

- **§Prefer gains a freshness tiebreak** — between otherwise-comparable candidates, prefer the
  healthier `decay`/`review_by` posture; a stale winner still wins but gets caveated.

- **Step 0's returning-session sync no longer HALTs when the remote has advanced.** The sync fetch
  carried `--depth 1` against an already-shallow clone, which re-shallows to the new tip instead of
  extending history toward the local one — `merge --ff-only` then failed "refusing to merge
  unrelated histories" and the session HALTed claiming unpushed local commits it did not have. If
  your operators have been running `reset --hard` on advice from that error, they were resetting a
  clone that was never diverged. Nothing to do: the fix ships in the plugin.

- **Step 0 resolves `{DEFAULT_BRANCH}` itself.** A Hive with `default_branch: main` no longer
  false-HALTs a returning session with `HALT_ORPHANED_BRANCH` — the branch-normalize check needed
  the value before the script reads `hive.yml`, and a session that has never read `hive.yml` could
  only guess `master`. Resolution order: `hive.yml` → `refs/remotes/origin/HEAD` → `master`. The
  sparse-checkout set gains `/CLAUDE.md`, `/README.md`, `_metrics/`, and `.signal/` — all four were
  read or written by sessions and audit without ever being checked out. The Identity parse list
  gains the push modes, the `classification` block, and the `federation` block, which later steps
  in the same file already dispatched on.

### 2.23.0 — inbox queue-branch transport (recommended default for new Hives)

- **New optional `hive.yml` fields `inbox_transport` (`default-branch` | `branch`) and
  `inbox_branch` (default `inbox`).** Under `branch`, sessions push inbox entries to a dedicated,
  never-PR-gated queue branch; Parliament is the only bridge to the default branch, which can then
  carry full vanilla protection (required PR + codeowner review on everything — no policy-bot, no
  CODEOWNERS narrowing). Unreviewed content never enters default-branch history, and queue history
  is cheaply rewritable for incident response. Design: `references/inbox-transport-design.md`.
- **`branch` is the recommended transport and the scaffolded default for NEW Hives** (create mode
  Q5.35 / `hive.yml.template`). For **existing** Hives, nothing changes: an absent field means
  `default-branch` — deliberately, so no Hive flips transports on a plugin update. Audit Step 4b
  offers the migration to existing Hives as an INFO recommendation; adopting it is a codeowner
  decision executed via the steps below.
- **No action required.** A Hive without `inbox_transport` behaves exactly as before, byte for
  byte. The fields are optional; nothing is migrated automatically.
- **Opt-in migration (per-Hive, reversible, no flag day):**
  0. **Pre-flight — refname collision check.** `git ls-remote --heads origin '<inbox_branch>/*'`
     (default `inbox/*`). Any hit is a legacy pr-mode inbox branch: git cannot create the ref
     `inbox` while `inbox/…` branches exist, so every session's bootstrap would be rejected.
     Merge/close those PRs and delete their branches first, or pick a non-colliding
     `inbox_branch` (e.g. `inbox-queue`).
  1. Set `inbox_transport: branch` in `hive.yml` via the normal protected-path PR — and in the
     same PR add `.parliament/` and `.inbox-worktree/` to the Hive's `.gitignore` (keeps the
     queue-push worktree out of any broad `git add`). New sessions start queueing on their next
     invocation — the first push bootstraps the queue branch as an orphan root.
  2. Run Parliament. During the cutover it drains **both** legacy `_inbox/` files still on the
     default branch and the queue — the coexistence window has no deadline, so sessions running a
     stale `hive.yml` (or an older Apiary) keep landing on the default branch and keep being
     drained.
  3. **Before protecting the default branch, gate on straggler extinction, not just queue
     health:** announce the cutover, then verify a quiet window with
     `git log --since=<window> origin/<default_branch> -- _inbox/` — authors still landing legacy
     inbox commits are stragglers on an old Apiary or a stale clone; chase them before flipping.
     Then apply vanilla branch protection, set `parliament_push_mode: pr` (and
     `sources_push_mode: pr` if the Hive uses native Deposit). Protecting the default branch is
     deliberately **last** — flipping it first would strand legacy-transport sessions mid-window.
     **Straggler net:** in the same change, set `inbox_push_mode: pr`. Current clients ignore it
     under the branch transport, but a pre-2.23.0 client — which cannot see `inbox_transport` —
     resolves inbox mode to `pr` and opens a visible, reviewable PR instead of having its direct
     push invisibly rejected (the contribution would otherwise be lost with only a generic
     warning). Audit Step 4b reports the field as intentional during the window; remove it once
     the fleet is confirmed on ≥2.23.0.
  3b. **Tear down the legacy pr-mode apparatus, if this Hive ever ran it** (same change as the
     protection flip): delete `.policy.yml`'s inbox-only zero-approval rule (or the file), remove
     policy-bot from the required status checks / revert the owners-bot flags
     (`required-approving-review-count` back to ≥1, native code-owner review re-enabled), and
     restore `CODEOWNERS` coverage by deleting the ownerless `_inbox/` line. Left in place, that
     machinery lets an inbox-only PR auto-merge into the "protected" default branch with zero
     review — silently voiding the transport's no-unreviewed-history guarantee. Audit Step 4b
     FAILs on leftovers.
  4. Add the "Inbox Queue Safety" ruleset (block deletion + force push on the queue branch only).
  5. **Rollback (order matters):** FIRST relax the default-branch protection — or stand up the
     full pr-mode apparatus (`references/push-mode-pr-setup.md`) and set `inbox_push_mode: pr` —
     and only THEN revert `inbox_transport`. Reverting first leaves sessions resolving to a
     direct push that the still-protected branch rejects: capture wedges and contributions are
     lost (audit Step 4b check 1b catches this state). Finally run Parliament once to drain the
     queue. No knowledge or attribution is destroyed in either direction.
- Under the branch transport, `inbox_push_mode` is ignored by current clients (audit Step 4b
  flags it as dead config outside a migration window), and the Parliament lock becomes an atomic
  `parliament/lock` ref — which also fixes the non-atomic `pr`-mode concurrent-run detection for
  Hives on this transport.

### 2.22.0 — Loop B telemetry, restatement dedup, two design proposals

- **Loop B gains telemetry parity with C/D:** gap contributions carry `coverage-gap:` /
  `routing-gap:` / `unreachable:` prefixes; Parliament rebuilds `loop-b-gaps.json`; audit and
  Brief consume it. **Migration: none** — unprefixed legacy gap entries simply do not aggregate;
  they age out of the 90-day window naturally.
- Co-loaded restatements deduped to single owning surfaces (workflows §Ask, cross-hive guard,
  custodian routing table, mode-operate loop enforcement). No semantic change.
- Design proposals added (not yet protocol): configurable deliberation-MERGE disposition;
  `/apiary audit --fix` remediation pass.

### 2.21.0 — compact RLDP rendering

- `protocol/routing-protocol.md` compressed ~31% (277 → 189 lines) by moving design rationale to
  `references/external-retrieval-design.md`; all step names, rules, and golden-pinned sentences
  unchanged. **Migration: none** — personas already reference the file by name and section.

### 2.20.0 — consistency + deterministic enforcement

- **One MERGE disposition rule** (custodian §4.3, with a Loop D carve-out): clean MERGE
  auto-merges; MERGE-with-objection or a second-challenged `[contradiction]` goes to needs-review.
- **Sentinel:** frontmatter + `sources/**.txt` scanning; classification-banner scan baked from the
  Hive's ceiling; excerpt-bound overrides (`sentinel_override.matches`); 18 patterns with a
  positive test each (two long-broken regexes fixed); Parliament §0 runs the hook's `scan-dir`
  as a literal command; quarantine redacts.
- **Loops C/D wired:** §4.1.05 prior-contradiction check; §6.2 idempotent telemetry rebuild;
  housekeeping stages the telemetry files.
- **RLDP:** §Recurse boundary defined; sufficiency verdict stated in one line; mechanical recency
  ranking; §On no match counts local reads and covers-answers as grounded; §Answer completion
  gates. Golden Cases 13–14 added.
- **Migration:** none required. Existing overrides without `matches:` keep legacy file-wide scope —
  add `matches` on next touch. Hives get the hardened hook on their next operate run.

### 2.19.0 — live store search (RLDP §Search)

- **New step `§Search`.** The RLDP could reach a document it had indexed but never one it had not. A
  `type: index` catalog is a point-in-time view of a store that keeps being written to, so material
  uploaded after the last trawl was invisible. §Search widens the corpus with a live store query.
  It is a rule invoked on a sufficiency judgment, not a no-match fallback: it has a **miss** path
  (routing found nothing, but a `## Scope` matched) and an **augment** path (routing found something
  that cannot answer — most often a recency-shaped question a trawl-dated row cannot serve).
- **Guards.** No `## Scope` match ⇒ no search. Selection may use path-inferred metadata; citation may
  not — the winner is opened through §Resolve/§Extract before it appears in an answer. Search is
  scoped to the roots a catalog declares in `sources[]`; tenant-wide requires explicit user direction.
- **Promotion, via the inbox.** An opened search-discovered document is promoted by a `[link]`
  contribution carrying the finished catalog row, marked `discovered_via: search`; Parliament appends
  it on the fast path. Promotion requires a read — `covers` must be content-derived, never inferred
  from a filename — and a read that disproves relevance still promotes, with corrected `covers`.
  Sessions never write `knowledge/`.
- **Runs as a subagent** (`protocol/external-search-agent.md`): search output is high-volume and
  mostly discarded, so the noise stays out of the session's context. Effort tier and scope are
  settled before dispatch, because a subagent cannot prompt. The tier sets how hard to look, not how
  many results are allowed — every hit clearing the tier's relevance bar is opened and promoted, and
  an over-broad query is narrowed and reported rather than silently truncated.
- **A newer revision of a catalogued document is a discovery, not a duplicate** — promoted carrying
  `supersedes`. A catalog goes stale by revision more often than by omission.
- **`tool-tiers.md` gains a Search column**; capability is split by filter-vs-order, since only some
  stores can be asked for their newest material.
- **New optional field `discovered_via`** in `document-quality.md` (mirrored to Second Brain per the
  shared-taxonomy contract). Audit Step 2b adds a catalog staleness check and counts unreviewed
  search-promoted rows.
- **Migration:** none required. §Search is additive; a Hive with no search tool installed degrades
  per § Degradation Patterns and records the gap.

### 2.16.1 — pre-push hook diffs against the merge base, not the empty tree

- **Fixes over-reporting on every first push of a branch.** `list_sentinel_changes` resolved its
  base with `git merge-base <local> HEAD@{upstream}` falling back to `git hash-object -t tree
  /dev/null` — the empty tree. A branch with no upstream therefore diffed against nothing, so the
  hook reported *every* `_inbox/` and `sources/` file in the Hive as changed.
- **Why it matters more than it looks.** Every contribution starts on a fresh branch, so this was
  not an edge case — it was the normal path. For the pattern scan, over-reporting is merely
  wasteful. For gate extensions it is wrong: a gate receives the file list as its argument set and
  reasonably reads it as "this contribution", so a gate asserting a per-contribution property (an
  attestation, a sign-off) would demand it for every pending entry in the repo, including other
  people's. A check that asks for that gets routed around with `--no-verify`, which skips every
  layer including the Sentinel.
- **New resolution order**, each step falling through on failure: the branch's own upstream →
  `origin/<default_branch>` then `<default_branch>` → `origin/HEAD` → the empty tree.
- **`default_branch` is now baked into the generated hook** from `hive.yml` at generation time
  (`DEFAULT_BRANCH=`), alongside the gate array. A hook generated without a `HIVE_ROOT` gets an
  empty value and falls through to `origin/HEAD`.
- **The empty-tree fallback is now loud.** It remains the last resort — over-reporting is the safe
  direction for the pattern scan — but it prints to stderr, because a gate behaving oddly on a
  first push is otherwise very hard to diagnose.
- **No action required.** No `hive.yml` schema change. Existing Hives get the corrected base on
  their next operate run, when the hook is regenerated. A Hive with no gates sees only a smaller
  scan.
- Regression coverage: `tests/sentinel-base.test.sh` (12 assertions). The failure was invisible to
  the obvious test — a gate that over-reports still blocks bad content — so the fixtures
  deliberately include a pre-existing inbox entry from an unrelated contribution.

### 2.16.0 — external retrieval is a first-class routing step

- **RLDP `Load` split into `Resolve` + `Extract`.** Resolve turns a locator into content and
  dispatches on locator kind (local file, directory pointer, absolute URL, store-relative path);
  Extract takes the needed part and dispatches on granularity (`§` anchor, catalog grep, whole).
  This makes "grep a catalog in an external store" and "load one section of a fetched document"
  expressible, which the previous flat list could not do.
- **Steps are now named, and `Prefer` is a rule rather than a stage.** Cite steps by name
  (`§Resolve`, `§On no match`) — names survive renumbering. `Prefer` applies wherever a candidate
  set appears: to matched reference-library entries, and again to matched catalog rows, which is
  where `authority` and `doc_type` actually live. §Recurse applies it before resolving rows, so a
  catalog hit ranks its rows instead of fetching all of them.
- **Reaching indexed-but-not-held material is required, not optional.** When an entry points at a
  document in SharePoint / Box / Quip / Confluence / Jira / a git host, the agent retrieves it
  rather than paraphrasing a local summary. An unresolvable locator or a missing tool is stated
  explicitly and recorded per §On no match.
- **New required catalog field: `covers`.** A catalog row now carries the document's topical
  content — the subjects a question is matched against. Without it a row is matchable only by
  filename, so a document that directly answers a question can be missed entirely. This is the
  catalog's equivalent of a reference-library `Triggers` column. Existing catalogs use several names
  for it (`Purpose`, `One-liner`, `Note`, `Contents`, `Covers`); those count as present and Audit
  reports the legacy name as INFO to rename on next edit.
- **`type: index` catalogs must declare a store root** in frontmatter `sources[]` (`url` + `type`)
  when their rows carry store-relative locations. This formalizes a convention catalogs were
  already following; it is what makes a row like `06 - Ground Segment/ICDs/` resolvable.
- **`tool-tiers.md` gains sharepoint / box-skill / quip-mcp rows** and a Store Kind → Tool table.
  The file remains mechanics-only and lazily loaded — it says which tool opens which store, never
  whether a document should be fetched.
- **New audit checks (Step 1c):** catalogs with no `covers` column (WARN) or a legacy-named one
  (INFO); catalogs with store-relative rows but no declared store root (WARN); store kinds with no
  tool mapping (INFO). Step 1b no longer misreports an external URL in a Source cell as a broken
  local pointer.
- **No action required.** No `hive.yml` schema change and no child-repo restructuring. Existing
  Hives get the new routing behavior on their next invocation. Expect new audit WARNs on the next
  `/apiary audit` where catalogs predate the store-root and `covers` requirements — these describe
  pre-existing unreachability, not new breakage. Fix by adding `sources[]` with `url` + `type`, and
  a `covers` column, to the catalog.

### 2.15.0 — gate extensions (Hive-specific pre-push hardening)

- Added optional `hive.yml` field `extensions.gates`: a directory of gate-extension files declaring
  extra pre-push checks, baked into the generated hook by operate mode Step 0. Gates run only after
  the built-in Sentinel pattern scan passes and cannot suppress a built-in match.
  See `references/authoring-gate-extensions.md`.
- **No action required.** A Hive that leaves `gates` unset (or omits it entirely) gets behavior
  identical to the pre-gate hook — the generator emits an empty gate array and the hook takes the
  same path.
- **Operate mode no longer overwrites a foreign `.githooks/pre-push`.** Previously the hook was
  regenerated unconditionally on every invocation, which silently replaced any Hive that had
  hardened its hook by hand — and printed `SENTINEL_HOOK_OK` while doing it, so the downgrade was
  invisible. Step 0 now checks for the generator's marker (resolved via
  `generate-hook.sh --print-marker`, so the two can never drift) and prints
  `SENTINEL_HOOK_PRESERVED_FOREIGN` instead of clobbering.
- **Recommended for Hives with a hand-rolled pre-push hook:** migrate the extra checks to
  `extensions.gates`. A preserved foreign hook keeps working but is frozen — it will not pick up
  new Sentinel patterns as upstream adds them. Audit Step 5 now flags this, and
  `references/authoring-gate-extensions.md` § "Migrating a hand-rolled hook" has the procedure.
  Do not delete a foreign hook to silence the warning without reading it first; it usually exists
  because someone deliberately hardened it.

### 2.13.2 — learning loops get names alongside their letters

- **Each loop now has a name:** A = **Correction**, B = **Discovery**, C = **Calibration**,
  D = **Escalation**. `protocol/learning-loops.md` carries the canonical letter→name mapping table.
- **The letters are unchanged and still valid.** Names are additive — headings read
  `## Loop C (Calibration): …`. Existing PR history, review comments, and the telemetry filenames
  (`loop-c-counters.json`, `loop-d-disputes.json`) continue to resolve.
- **Why:** a bare letter does not say whether a loop acts on facts (A, B), on the policy governing
  facts (C), or on confidence in a fact (D) — and the letters collide with the second-brain skill,
  where Loop A means something different (corrections → agent *rules*, not → knowledge).
- **No action required.** Documentation only: no mechanism, threshold, `hive.yml` schema, or
  telemetry path changed.

### 2.13.0 — learning loops: findability, Loop C reconciliation, Loop D enforcement

- **Loop B now includes findability.** Capture and indexing are one obligation: a knowledge file
  no reference-library entry points at is a Loop B failure, not just a routing warning. Sessions
  owe a `[link]`/`[process]` inbox entry whenever they hit a routing gap.
- **Loop C wording reconciled.** The canonical mechanism is approval ratios tuning the triage
  policy; two runtime surfaces described it as checklist growth.
- **Loop D is now enforced.** It was defined in `learning-loops.md` but absent from operate-mode
  enforcement, audit Step 3, and the audit report template. All three now cover it.
- **Directory pointers are canonical.** A reference-library Source cell may name a directory
  (`people/profiles/`), covering every `.md` beneath it. Audit now resolves them, which removes a
  class of false orphan.
- **New audit output:** routing coverage counts, measured fast-path share vs the ~80% prediction,
  and Loop C/D telemetry presence.
- **No action required.** No `hive.yml` schema change. Existing Hives get the new audit checks on
  their next `/apiary audit`; expect new WARNs that reflect pre-existing state, not new problems.

### 2.12.0 — RLDP consolidation, version-check repair

- **`protocol/routing-protocol.md` is new** and is now the canonical Reference Library Discovery
  Protocol. `assets/agent-definition-template.md` references it instead of inlining the steps.
- **Why:** the RLDP was copied into each Hive's `PROTOCOL/agent-definition.md` at create time,
  and upgrade mode never rewrites the persona — so an upstream improvement reached zero existing
  Hives. Three incompatible variants (3-step, 6-step, 7-step) drifted into production.
- **New upstream behavior:** the RLDP now *requires* recording a coverage gap as an inbox
  contribution when no trigger matches (§On no match).
- **Action:** run the persona migration below. It is **not** auto-applied — the persona is
  child-owned content and rewriting it needs a human in the loop.
- The `hive.yml` version-check path in `SKILL.md` was also repaired (it pointed at a
  nonexistent `skills/.claude-plugin/` and so never fired), and `hive.yml.template` no longer
  seeds a hardcoded `1.0.0`.

#### Persona migration: adopt the upstream RLDP (recommended, not automatic)

Applies to any Hive whose `PROTOCOL/agent-definition.md` still contains an inline
`## Reference Library Discovery Protocol` section.

1. Detect: `grep -n "Reference Library Discovery Protocol" {HIVE_ROOT}/PROTOCOL/agent-definition.md`
2. If an inline numbered step list follows that heading, the Hive is on a frozen variant. Report
   which variant it carries (count the steps) and whether it has a no-match branch.
3. Replace **only** that section's body with the pointer form from
   `assets/agent-definition-template.md` § Reference Library Discovery Protocol. Leave the
   Hive's routing table, persona voice, and behavioral constraints untouched.
4. This edits `PROTOCOL/`, which is CODEOWNER-protected — open a PR, never push direct. Per
   `protocol/security-policy.md` § Repository Protection Model, `PROTOCOL/**` is blocked for
   direct push.
5. If the Hive's inline variant contains routing behavior **not** present upstream, do not
   discard it: capture it as a `[meta]` inbox contribution so it can be considered for the
   upstream protocol. That is how the §On no match rule arrived.

### 2.11.0 — Apiculturist registry reconciliation

- Parliament §1.4 no longer refreshes the sibling roster inline. It dispatches the **Apiculturist**
  subagent (`protocol/apiculturist-workflow.md`), which additionally **upserts this Hive's own row**
  in the Hive Mind Registry — inserting it if missing, updating drifted `Apiary ver` / purpose /
  owners / slack / classification.
- The reconcile is now **ungated**: it runs on every Parliament, not only when the inbox work set is
  non-empty. A Hive with a quiet inbox is the one most likely to have a stale or missing row, and the
  old gate always skipped exactly that case.
- The Apiculturist is the **single writer** of a Hive's registry row. `upgrade` bumps
  `hive.yml.upstream_version` (Step 3) and stops there; the next Parliament reconciles the row. There
  is no registry write in upgrade mode, so the two can never conflict.
- `/apiary audit` gained **Step 4c**, a read-only registry drift check (row missing, `Apiary ver`
  mismatch, metadata drift, stale sibling cache). Audit still needs no Confluence write auth.
- Added the optional `hive.yml.federation` block — two independent opt-outs, both defaulting to `true`:
  `register` (publish/maintain this Hive's registry row) and `cross_hive_routing` (suggest mis-filed
  contributions to siblings). Setting both `false` makes the Hive self-contained: Parliament skips the
  Apiculturist and never contacts Confluence. `register: false` does **not** delete an already-published
  row — retraction is deliberately manual, and audit Step 4c reports the mismatch so a codeowner can do
  it. Neither switch is a security control; classification remains the direction guard's job.
- **No action required** for a Hive created at 2.5.0 or later — it already has `confluence_registry`
  and `purpose`, so the Apiculturist works on the next Parliament run. A Hive with no `federation:`
  block participates exactly as before, so the opt-outs need no migration either.
- **Action required for Hives created before 2.5.0** — see the migration below. Without
  `confluence_registry` the Apiculturist exits early and the Hive stays invisible to registry
  reconciliation, exactly as the old §1.4 did.

### 2.6.0 — per-flow push mode

- Added optional `hive.yml` fields `inbox_push_mode` and `parliament_push_mode`. Each overrides the
  shared `push_mode` for its flow; resolution is *specific override → `push_mode` → `direct`*.
- **No action required.** A Hive with only `push_mode` set behaves exactly as before.
- **Recommended for Hives currently on `push_mode: pr`:** split to `inbox_push_mode: direct` +
  `parliament_push_mode: pr` so inbox contributions are captured straight to the default branch
  while `knowledge/` merges stay gated behind a codeowner PR. `/apiary audit` (Step 4b) detects this
  and offers to configure it. See `references/push-mode-pr-setup.md`.
- **Caveat:** `pr` mode requires branch protection — on an unprotected branch `gh pr merge --auto`
  is rejected and PRs never merge. Audit Step 4b flags this as a FAIL.

## Current Migrations

### Migration: pre-2.5.0 → 2.11.0 (registry federation backfill)

**Applies to** any Hive whose `hive.yml` lacks `confluence_registry` or `purpose` — i.e. one created
before the 2.5.0 federation feature. Such a Hive may well already appear in the registry (rows were
hand-backfilled at various points), but the protocol cannot see or correct its row.

**Non-breaking.** A Hive that declines this migration keeps operating normally; it simply stays
invisible to registry reconciliation and cross-hive routing. Nothing else regresses.

#### hive.yml changes
- Added field `confluence_registry` — URL of the canonical registry page
- Added field `purpose` — what knowledge belongs in this Hive (and what does not)

#### Auto-apply
1. If `confluence_registry` is missing, add
   `confluence_registry: "https://confluence.meridian.example/pages/viewpage.action?pageId=100000001"`.
   Single canonical default; safe to apply without asking.
2. If `siblings` is missing, add `siblings: []`. It self-heals on the next Parliament run.

#### Requires human input
3. If `purpose` is missing, **prompt** — never invent it:

   > "In one or two sentences, what knowledge *belongs* in this Hive — and what does NOT? This becomes
   > the Purpose column in the Hive Mind Registry and the scoping signal Parliament uses to suggest
   > re-filing mis-placed contributions to a sibling Hive."

   Seed a suggestion from the README's "What Lives Here" section if one exists, but require the user to
   confirm or edit it. `purpose` drives cross-hive routing for *every other Hive*; a fabricated one
   silently mis-routes contributions. If the user declines, leave `purpose` unset and note that the
   Apiculturist will write the row with an empty purpose cell.

**Do not write the registry from upgrade mode.** After backfilling, tell the user: "Registered on the
next Parliament run — the Apiculturist is the single writer of your registry row."

### Migration: 1.x → 2.0

#### hive.yml changes
- Added required field `remote` — git remote URL for the Hive repo
- Added required field `default_branch` — default branch name (default: `master`)

#### Structural changes
- Removed `.apiary-protocol/` directory (protocol now read from installed Apiary plugin)
- Removed sync hook from `.claude/settings.json` SessionStart

#### Auto-apply
1. If `remote` is missing, prompt user: "What is the GHE remote URL for this Hive?"
2. If `default_branch` is missing, add `default_branch: master`
3. If `.apiary-protocol/` exists, delete it
4. If `.claude/settings.json` contains the `sync.sh` SessionStart hook, remove that hook entry

#### Requires human input
- `remote` URL (cannot be inferred)
