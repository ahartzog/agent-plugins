# Audit Mode — Hive Health Check

This document guides the Audit mode of the Apiary skill.

## Two Trigger Modes

### Manual Audit (`/apiary audit`)

Full deep check. Run on-demand by a CODEOWNER or contributor. Produces a health report.

### Post-Parliament Tail-Check (automatic)

Lightweight audit at the end of every Parliament run. Covered in `protocol/custodian-workflow.md` §0 "Post-Parliament tail-check." Does NOT produce a separate report.

This document defines the **manual audit** flow.

## Process

### Step 1: Structural Check

Verify the child repo matches expected layout:

Required files:
- `hive.yml` — exists, valid YAML, all required fields present
- `PROTOCOL/agent-definition.md` — exists, has frontmatter
- `CLAUDE.md` — exists
- `_inbox/` directory — exists
- `_inbox/_completed/` — exists
- `_inbox/_quarantine/` — exists
- `_custodian/config.yml` — exists, valid YAML
- `knowledge/` directory — exists, contains at least one `.md` file
- `.claude/settings.json` — exists, `git add` scoped to `_inbox/*`

Optional files (note if missing, don't fail):
- `knowledge/**/reference-library.md` — at least one (checked in Step 1b)
- `PROTOCOL/extensions/` directory
- `.signal/config.yml`
- `_metrics/`
- `README.md`

### Step 1b: Reference Library Check

1. Glob `knowledge/**/reference-library.md` — at least one must exist. If none: flag as **WARN: no reference-library found. Ask workflow cannot route to external sources.**
2. For each reference-library found:
   - Verify it has a `## Scope` header
   - Verify `type: reference-library` in frontmatter
   - For every source path — whether in the **Source cell** of a `Topic | Source | Triggers` table (the default format) or after a `**Source:**` label (block form) — verify the target file exists AND, if a section is given after `§`, that the section header exists in that file. Flag broken pointers (missing file or missing section). **Extract source paths format-agnostically, and prefix-tolerantly.** Table cells are written relative to `knowledge/` (`program/overview.md`); block `**Source:**` labels historically carry the full `knowledge/…` prefix. Both are valid: pull `.md` path tokens from the Source cell/label only (not from Topic or Triggers text, which would flag prose `.md` mentions as broken pointers), match `` `?(?:knowledge/)?[^ |`]+\.md `` , and resolve any non-`knowledge/`-prefixed path against `knowledge/` before checking existence. Without this, a tabular library (relative paths) reads as every-entry-broken and every-file-uncovered.
   - **Also extract directory pointers** — Source tokens ending in `/` (e.g. `people/profiles/`), matched as `` `?(?:knowledge/)?[^ |`]+/ `` . Verify the directory exists and contains at least one `.md`; flag an empty or missing directory as a broken pointer. These are a canonical Source form (`protocol/knowledge-schema.md` § Reference Library Entry Format) and are load-bearing for the coverage check below — a `.md`-only regex misses them and reports every file in a pointed-to directory as an orphan.

     **Two extraction guards:**
     - **Discard a token that normalizes to empty** (a bare `` `/` ``, or `./`). An empty directory prefix matches *every* path and marks the whole corpus covered, so the check reports zero orphans and the failure looks like success.
     - **Ignore absolute and `~`-rooted tokens** (`~/repos/platform-apis/`, `/etc/...`). Those are external filesystem pointers, not `knowledge/` subdirectories, and must not count as coverage.
   - **External locators are not broken local pointers.** A Source cell may carry an external URL (`https://…`) — the escape-hatch form in `protocol/knowledge-schema.md` § Reference Library Entry Format. Do not resolve these against `knowledge/` or report them as missing files. Count them and report as **INFO: {N} reference-library entr(ies) point directly at an external URL — the preferred form is a `type: index` catalog that declares a store root. Consider promoting these.** Reachability of the URL itself is not audited (no network dependency).
   - Check token footprint: reference-libraries should be thin routers. Flag any over 200 lines as **WARN: reference-library may be too large — convert block entries to `Topic | Source | Triggers` table rows (the denser default) before cutting coverage; check for duplicated content that belongs in knowledge files.**
3. **Coverage check:** For each knowledge file in `knowledge/`, verify at least one reference-library entry points to it — resolving Source paths the same prefix-tolerant way (relative table cells and full-path `**Source:**` labels both count), **and treating a directory pointer as covering every `.md` beneath it**. Flag uncovered files as **WARN: knowledge file has no reference-library entry — invisible to Ask routing.**

   **Report the two classes separately** — they have different fixes:
   - *Uncovered by any entry or directory pointer* → a genuine routing gap; needs a new entry.
   - *Covered only by a directory pointer* → reachable, but only by scanning the directory. Not a defect; do not flag. Report the count as INFO so a Hive can see how much of its corpus is reachable only in bulk.

   A `.md`-only matcher misreports every directory-pointer-covered file as an orphan, so resolving directory pointers is required for this check to mean anything.

### Step 1c: Catalog Structure Check

**Scope:** This check applies ONLY to knowledge files with `type: index` in frontmatter — document catalogs that point to external files (SharePoint, Confluence, vendor deliverables). It does NOT apply to `type: reference-library` files (routing indexes), `type: reference` files, or other knowledge files that happen to contain markdown tables.

For each `type: index` knowledge file:

1. Verify that markdown tables containing document entries have `doc_type` and `authority` columns. Tables without these columns are flagged as **WARN: catalog table missing doc_type/authority columns — see protocol/document-quality.md.**
2. **Topical matchability (`covers`).** Verify document-entry tables carry a `covers` column — or an equivalent under a legacy name (`Purpose`, `One-liner`, `Note`, `Contents`, `Covers`), which counts as present. A table with none is flagged as **WARN: catalog rows carry no `covers` text — routing can only match these rows by filename, so questions this catalog should answer will miss. See protocol/document-quality.md § covers.** Report legacy-named columns as **INFO: `covers` column named "{name}" — canonical name is `covers`, rename on next edit.** Do not flag individual empty cells; this is a column-level check.
3. Spot-check `authority` values: scan for any value not in {`formal`, `baseline`, `delivered`, `working`}. Common violations: organization names (e.g., `Orbital Dynamics`, `Nova Launch`), compound values (e.g., `cdrl, formal`), or person names. Flag as **WARN: non-standard authority value "{value}" — should be one of {formal, baseline, delivered, working}. Use source_org for organization names.**
4. Verify that catalog files with vendor/external documents include a `source_org` column (not required for purely internal catalogs).
5. Check catalog file size: flag any over 500 lines as **WARN: catalog may be too large for efficient Ask routing — consider splitting by domain or adding section anchors to reference-library entries.**
6. **Store root declared (resolvability).** If the catalog's rows carry store-relative locations — a location/path column whose cells are neither absolute URLs nor in-store `knowledge/`-relative paths — verify frontmatter `sources[]` declares at least one entry with **both** `url` (the root) and `type` (the store kind). If absent, flag as **WARN: catalog rows are store-relative but no store root is declared in `sources[]` — every row is unresolvable, so Ask can only return addresses. See `protocol/knowledge-schema.md` § Store Roots for `type: index` Catalogs.** This is the external-side counterpart to Step 1b's broken-pointer check: 1b verifies local Source paths resolve, this verifies external rows can.

   **In-store cells are not store-relative — exclude them before applying this check.** A `knowledge/`-relative `.md` path (`internal.md`) *and* a `knowledge/`-relative **directory pointer** (`profiles/`, trailing slash — canonical per `protocol/knowledge-schema.md` § Reference Library Entry Format, and resolved by Step 1b above) both point inside the Hive. A catalog whose locator column holds only these is fully in-store and **must not** be flagged. Resolve the candidate against `knowledge/` first: if it exists on disk, it is in-store, not store-relative. Without this exclusion an entirely local catalog reports "every row is unresolvable," which is the opposite of true.

   **One root per store.** When rows point into more than one store, verify a `url`+`type` entry exists **for each store present**, not merely that one exists. A catalog declaring only a SharePoint root while also carrying GHE or Jira rows leaves those rows unresolvable; flag as **WARN: rows reference store(s) {list} with no declared root — only {declared} is declared.**
7. **Store kind is reachable.** For each declared `sources[].type`, check it appears in `protocol/tool-tiers.md` § Store Kind → Tool. Flag an unknown value as **INFO: store kind "{value}" has no tool mapping — Ask will not know how to reach it. Add a row to tool-tiers or correct the value.** INFO, not WARN: a Hive may legitimately reach a store the standard set does not name yet.

This step is informational (WARN, not FAIL) — catalogs may legitimately vary in structure during initial population.

### Step 1d: Persona Routing-Protocol Drift Check

The Reference Library Discovery Protocol is upstream-owned (`protocol/routing-protocol.md`). A
persona that carries its own inline copy is frozen at whatever Apiary version scaffolded the
Hive and will not pick up routing improvements.

1. `grep -n "Reference Library Discovery Protocol" PROTOCOL/agent-definition.md`
2. If the heading is followed by an inline numbered step list, flag:
   **WARN: persona carries an inline RLDP copy ({N} steps) — frozen variant, will not receive
   upstream routing improvements. Migrate to the pointer form (see `references/mode-upgrade.md`
   § "Persona migration: adopt the upstream RLDP").**
3. Report whether the inline variant has a **no-match branch** (a step that records a coverage
   gap when no trigger matches). If it does not, add:
   **WARN: inline RLDP has no no-match branch — questions the reference-library misses are
   answered silently and the gap is never recorded, so the same question fails next session.**
4. If the persona references `protocol/routing-protocol.md` instead of inlining steps: PASS.

### Step 2: Freshness Check

For each knowledge file in `knowledge/`:
1. Read `last_updated` from frontmatter
2. Compare against today's date
3. Flag files where `last_updated` is older than the decay threshold:
   - `decay: fast` → stale after 14 days
   - `decay: medium` → stale after 60 days
   - `decay: slow` → stale after 180 days

### Step 2b: Catalog Staleness Check

**Scope:** `type: index` catalogs only. Step 2's Freshness Check reads `last_updated` against a `decay:` threshold, but that governs `knowledge/` content files; a `type: index` catalog is a **point-in-time view of a store that keeps being written to**, so it drifts on its own even when nobody touches the Hive (`references/external-retrieval-search-design.md` § The third indistinguishable failure). This check is the read-side half of that problem.

For each `type: index` knowledge file:
1. Read `last_updated` from frontmatter. **A catalog with no `last_updated`, or an unparseable one, is a WARN — not a pass.** An absent date makes every comparison below vacuously true, so treating it as fresh would report the whole corpus clear without checking anything.
2. Compare against today's date using the catalog's `decay:` threshold if set, else the `slow` threshold (180 days) — a catalog is a durable index, not fast-moving content.
3. Flag a catalog whose `last_updated` trails the threshold as **INFO: catalog `last_updated` is {N} days old — the store it indexes may have been written to since the last trawl. Recommend a re-trawl to refresh coverage.** This is a re-trawl recommendation, **not** a defect: the rows present are still valid, they are simply an incomplete view of a live store.
4. Count rows marked `discovered_via: search` per catalog and report the total as **INFO: {N} rows promoted by live search, placement not yet human-reviewed.** The marker asserts a review is owed (`protocol/document-quality.md` § discovered_via); without a count nothing surfaces that debt, and unreviewed rows accumulate invisibly. Flag a catalog where such rows exceed half its total as a WARN — the catalog is now mostly machine-placed and deserves a curation pass.

**Why this check is required alongside §Search.** `protocol/routing-protocol.md` §Search repairs the corpus **one asked question at a time** (its miss path): it reveals only the specific row missing for the specific question, and structurally cannot report that a whole catalog has gone stale — nothing asks it to survey the store. Corpus-wide drift is therefore invisible to §Search and detectable only here. Shipping the miss-path repair without this detection would leave the Hive able to patch individual misses while never noticing its whole view of a store has drifted — the read-side half Goal 9 requires any new content surface to name (`references/external-retrieval-search-design.md` § What search does not fix).

### Step 3: Learning Loop Health

**Loop A — Correction (corrections → knowledge):**
- Count `[correction]` entries in `_inbox/_completed/` (rolling 90 days), using each file's reconciliation note (`verdict`, `pr`)
- For each `verdict: merged` correction, spot-check that the target knowledge file no longer shows the old value (grep for the corrected value where the note names one) — flag any merged correction whose target fact still reads the old way
- Flag `[correction]` entries still sitting unprocessed in `_inbox/` older than the Parliament cadence — corrections are the loop with the highest cost-of-delay (a known-wrong fact keeps being served)

**Loop B — Discovery (discoveries → knowledge, *and* findability):**
- Check recent inbox `_completed/` files for `[learned:]` annotations
- Compare against knowledge file `last_updated` dates
- Flag if inbox shows activity but knowledge files haven't been updated
- **Findability half of the loop:** carry forward the Step 1b coverage result. Genuinely uncovered knowledge files (not covered by a file *or* directory pointer) are Loop B failures, not just routing warnings — content was captured but never made reachable. Report as `Loop B: {N} uncovered file(s) — captured but unreachable by Ask`.
- Read `_custodian/reports/loop-b-gaps.json` if present: report the top 5 gaps by count (a
  count ≥ 2 means multiple sessions hit the same wall) and the `unreachable` total (store-root /
  tool debt). If absent on a Hive whose Parliament has run since 2.22.0: **WARN: no Loop B
  telemetry — recorded gaps are not being aggregated, so the gap backlog is invisible.**
- Check `_inbox/` and `_inbox/_completed/` for routing-gap contributions (`[link]`/`[process]` entries naming a question the reference-library could not answer, or a locator that would not resolve, per `protocol/routing-protocol.md` §On no match). **Zero such entries in a Hive that also has uncovered files is a signal the loop is not firing** — sessions are hitting gaps and not recording them. Report as INFO with both counts side by side.

**Unratified agent decisions (epistemic provenance):**
- Scan `knowledge/` for `[decided: <who>, YYYY-MM-DD]` annotations where `<who>` is an agent id (e.g. `claude`) rather than a human name / CODEOWNER
- An autonomous agent decision is **ratified** when a human `[decided:]` annotation appears on the same fact (agent chose → human confirmed)
- Flag agent `[decided:]` markers with no accompanying human `[decided:]` as "unratified agent decision — surface for CODEOWNER review"; Parliament may open a `needs-review` PR for these
- **Severity:** Minor by default; Important when the fact lives in a `reference`/`register` file — autonomous agent choices in durable, shared content should not go unreviewed

**Loop C — Calibration (approval ratios → triage policy tuning):**
- Read `_custodian/reports/loop-c-counters.json`. If absent: **WARN: no Loop C telemetry — Parliament is not recording approval ratios, so the triage policy has no feedback signal and any change to the fast/deliberation split is unmeasured.**
- If present, report per-category approval rate and whether any category has crossed the ≥90% / 30-day threshold (see `protocol/learning-loops.md` Loop C). A crossed threshold should have produced a `[meta]` stub proposing fast-path promotion — flag if it did not.
- **Calibration cross-check (independent of telemetry):** compute the actual fast-path share from `_inbox/_completed/` — count entries whose `tag` is `link`/`person`/`tracker` over total tagged entries. `protocol/triage-policy.md` predicts ~80%. Report the measured value; flag a gap over 20 points as **WARN: fast-path share {N}% vs ~80% predicted — triage routing may be mis-weighted, or the prediction is stale. Loop C telemetry is the arbiter.**
- Frame this loop as *approval ratios tuning the triage policy* (`protocol/learning-loops.md` Loop C), not as checklist growth.

**Loop D — Escalation (contradiction velocity → auto-flag):**
- Read `_custodian/reports/loop-d-disputes.json`. If absent and the Hive has processed any `[contradiction]` entries: **WARN: no Loop D telemetry — repeat contradictions against the same fact are not being detected, so a contested fact can survive indefinitely.**
- Count `[contradiction]`-tagged entries in `_inbox/_completed/`, grouped by target fact/file. Any fact with ≥2 in a rolling 30-day window should carry a `[disputed:]` annotation in `knowledge/` and have a `needs-review` PR — flag any that does not as **WARN: repeat contradiction with no `[disputed:]` marker — Loop D did not fire.**
- Scan `knowledge/` for existing `[disputed:]` annotations and report them with age. A `[disputed:]` older than 30 days with no resolution is a stalled escalation.

### Step 4: Version Check

Compare `hive.yml.upstream_version` against Apiary's current version.
- Current: report as healthy
- Behind (minor/patch): note that protocol improvements are already live
- Behind (major): flag as requiring upgrade, offer to run upgrade

### Step 4b: Push Mode Health Check

Validates how the Hive pushes inbox contributions and Parliament runs. The failure this
catches is silent: a Hive configured for `pr` on an unprotected branch opens PRs that never
auto-merge, so contributions sit open and are effectively lost.

First, resolve the transport, then the effective mode for each flow (same resolution the runtime uses):
- **transport** = `hive.yml.inbox_transport`, default `default-branch`; **queue branch** = `hive.yml.inbox_branch`, default `inbox`
- **inbox mode** = `hive.yml.inbox_push_mode` if set, else `hive.yml.push_mode`, else `direct` — **ignored when transport is `branch`** (the queue is direct-push by construction)
- **parliament mode** = `hive.yml.parliament_push_mode` if set, else `hive.yml.push_mode`, else `direct`

Then check branch protection on `{DEFAULT_BRANCH}` once (used by both paths below):

```bash
gh api "repos/{owner}/{repo}/branches/{DEFAULT_BRANCH}/protection" >/dev/null 2>&1 \
  && echo "protected" || echo "unprotected"
```
(A 404 "Branch not protected" means unprotected. If `gh` is unavailable or auth fails, mark
protection **UNKNOWN** and downgrade the checks below to informational — do not assume protected.)

**Queue-transport checks — run these when transport is `branch`, INSTEAD of the default-branch
checks further down** (those police the inbox-on-default-branch configuration this Hive has opted
out of):

1. **FAIL — queue branch is PR-gated.** Check **both** protection surfaces — legacy branch
   protection (`gh api "repos/{owner}/{repo}/branches/{INBOX_BRANCH}/protection"`) **and**
   rulesets (`gh api "repos/{owner}/{repo}/rules/branches/{INBOX_BRANCH}"`, which the legacy
   endpoint cannot see). If either imposes required PRs or required status checks on the queue:
   **FAIL: the inbox queue branch must never require PRs or checks — sessions push it directly; a
   gate here wedges capture. Keep only deletion/force-push protection (see
   `protocol/security-policy.md` § Transport = branch variant).**
2. **FAIL — Parliament cannot land.** If `{DEFAULT_BRANCH}` is protected and the resolved parliament mode is `direct`: **FAIL: `{DEFAULT_BRANCH}` requires PRs but Parliament is configured to push direct — housekeeping and knowledge merges will be rejected. Set `parliament_push_mode: pr`.** (Same check for `sources_push_mode` if the Hive uses native Deposit: a fully protected default branch needs `sources_push_mode: pr`.)
2b. **WARN — Parliament PRs will strand (the reverse pairing).** If the resolved parliament mode is `pr` and `{DEFAULT_BRANCH}` is **unprotected**: **WARN: `parliament_push_mode: pr` on an unprotected branch — GitHub only arms auto-merge on a PR blocked by a required check/review, so housekeeping PRs sit open until a human merges them, and under the merge-gated drain the queue lags accordingly (entries stay `PENDING_REVIEW`). Fix: apply the vanilla protection (the intended end-state — see check 6), or set `parliament_push_mode: direct` until you do.** This is the state a new Hive reaches by doing create-mode follow-up (3) before (1); nothing is lost, but the queue stops draining.
3. **FAIL — legacy `pr`-mode apparatus still live.** If the repo still carries the
   push-mode-pr-setup machinery — policy-bot in `{DEFAULT_BRANCH}`'s required status checks, a
   `.policy.yml` inbox-only zero-approval rule, or a `CODEOWNERS` file with an ownerless
   `_inbox/` override: **FAIL: leftover pr-mode apparatus lets inbox-only PRs merge into
   `{DEFAULT_BRANCH}` without review, voiding the transport's no-unreviewed-history guarantee.
   Complete the teardown in `references/mode-upgrade.md` § 2.23.0.**
4. **FAIL — refname conflict blocks bootstrap.** If the queue branch is missing AND
   `git ls-remote --heads origin "{INBOX_BRANCH}/*"` returns anything (legacy pr-mode inbox
   branches): **FAIL: the queue branch cannot be created while `{INBOX_BRANCH}/*` branches exist
   (git refname conflict) — every session's bootstrap is rejected. Merge/close those PRs and
   delete their branches, or set a non-colliding `inbox_branch`.**
5. **WARN — dead config.** If `inbox_push_mode` (or an inbox-relevant `push_mode: pr`) is set: **WARN: `inbox_push_mode` has no effect under `inbox_transport: branch` — remove it to avoid misleading a future operator.** Exception: during a migration coexistence window, `inbox_push_mode: pr` is the documented straggler net for pre-2.23.0 clients (`mode-upgrade.md` § 2.23.0) — if the Hive migrated recently, report it as INFO ("intentional during cutover; remove once the fleet is current") rather than WARN.
6. **WARN — protection goal unrealized.** If `{DEFAULT_BRANCH}` is unprotected: **WARN: the queue transport is configured but `{DEFAULT_BRANCH}` accepts direct pushes — the "unreviewed content never enters default-branch history" guarantee is not repo-enforced. Apply vanilla branch protection (require PR + codeowner review).**
7. **INFO — queue ruleset.** If no deletion/force-push protection exists on `{INBOX_BRANCH}`: recommend the "Inbox Queue Safety" ruleset.
8. **INFO — queue depth/age/hygiene.** Report `git ls-tree -r --name-only origin/{INBOX_BRANCH} | wc -l` and the oldest entry's last-commit age (an old queue means Parliament is not running often enough), and WARN-list any queue path not matching the conforming shape `_inbox/<name>.md` — non-conforming paths are unscanned by the session push path and wait on Parliament's janitor (`custodian-workflow.md` §1.3). A missing queue branch with no `{INBOX_BRANCH}/*` conflict (check 4) is INFO, not FAIL — it bootstraps on the first session push. Also list any `parliament/*` branches whose housekeeping PR is closed-unmerged: their queue files are stuck `PENDING_REVIEW` until the dead branch is deleted.

**Default-branch transport checks — flag the following when transport is `default-branch`:**

1. **FAIL — `pr` mode on an unprotected branch.** If either resolved mode is `pr` and
   `{DEFAULT_BRANCH}` is unprotected: **FAIL: {flow} push mode is `pr` but `{DEFAULT_BRANCH}` is
   unprotected. GitHub only arms auto-merge on a PR blocked by a required check/review, so
   `gh pr merge --auto` is rejected and these PRs never merge — contributions are lost. Fix: set
   `{flow}_push_mode: direct`, or protect the branch (see `references/push-mode-pr-setup.md`).**
1b. **FAIL — `direct` inbox mode on a protected branch.** The mirror failure — reachable after a
   queue-transport rollback that reverted `inbox_transport` before relaxing protection, or after
   protecting a branch without configuring an inbox path. If the resolved inbox mode is `direct`
   and `{DEFAULT_BRANCH}` is protected: **FAIL: direct inbox pushes are rejected by branch
   protection — capture is wedged and every session's contribution is lost. Fix: adopt
   `inbox_transport: branch`, or set `inbox_push_mode: pr` with the
   `references/push-mode-pr-setup.md` apparatus, or relax the protection.**
2. **WARN — `pr` Parliament mode with auto-merge unwired.** If parliament mode is `pr` and
   `hive.yml.auto_merge.mechanism` is `pending`: **WARN: Parliament opens PRs (`parliament_push_mode:
   pr`) but `auto_merge.mechanism: pending` means nothing auto-merges. Parliament PRs will wait for
   a manual merge. Set a real `mechanism`, or expect to merge Parliament PRs by hand.**
3. **INFO — per-flow overrides not set.** Evaluate **after** check 4's migration offer: if the
   user accepts the queue-transport migration, skip this check entirely — `inbox_push_mode`
   becomes dead config under that transport, so recommending it here would have the next audit
   warning about the config this one suggested. Otherwise: if **both** `inbox_push_mode` and
   `parliament_push_mode` are absent from `hive.yml` (i.e. the Hive relies solely on `push_mode`
   or the `direct` default), inform the user the overrides exist and **offer to configure
   them**. Present it as an optional improvement, not a defect:
   > This Hive uses a single push mode for both inbox contributions and Parliament. You can split
   > them: `inbox_push_mode` and `parliament_push_mode` override `push_mode` per flow. The common
   > setup is **`inbox_push_mode: direct`** (capture contributions aggressively — the inbox is a
   > low-cost buffer Parliament reviews downstream) **+ `parliament_push_mode: pr`** (gate
   > `knowledge/` merges behind a codeowner-reviewed PR). Want me to add these to `hive.yml`?

   If the user accepts, add the two fields to `hive.yml` with the recommended values (adjust if the
   branch is unprotected — `parliament_push_mode: pr` requires protection per check 1) and note the
   change in the report. If they decline, record the offer as declined and move on. Do not nag on
   subsequent audits beyond this single INFO line.
4. **INFO — queue-branch transport available (the recommended transport).** A Hive on the
   `default-branch` transport is on the legacy path: new Hives are scaffolded with
   `inbox_transport: branch` since 2.23.0, which keeps capture friction identical while letting
   `{DEFAULT_BRANCH}` carry full vanilla protection and keeping unreviewed content out of its
   history. **Offer the migration** — present it as the recommended upgrade, not a defect:
   > This Hive routes inbox contributions through `{DEFAULT_BRANCH}` (the pre-2.23.0 transport).
   > The recommended setup is `inbox_transport: branch`: same one-push capture, but the default
   > branch can then require PR + codeowner review on everything, and unreviewed session content
   > never enters its history. Migration is reversible and has a coexistence window — want me to
   > walk `references/mode-upgrade.md` § 2.23.0 with you (pre-flight checks first)?

   If the user accepts, follow the § 2.23.0 migration **in order** — the pre-flight refname check
   and the protect-last / teardown steps are load-bearing, not ceremony. If they decline, record
   the offer as declined; as with check 3, do not re-nag on subsequent audits. If the Hive
   currently uses `inbox_push_mode: pr` + the policy-bot apparatus, note that the migration
   retires that entire setup (its teardown is § 2.23.0 step 3b).

### Step 4c: Registry Reconciliation Check

Verifies this Hive is correctly represented in the [Hive Mind Registry](https://confluence.meridian.example/pages/viewpage.action?pageId=100000001).
The failure this catches is silent: a Hive whose row is missing or stale is invisible (or misleading)
to every *other* Hive's cross-hive routing, and nobody notices because nothing reports it.

**Read-only.** Audit never writes the registry — `/apiary audit` requires no Confluence write auth.
Drift is *reported*; the fix is a Parliament run, because the Apiculturist is the single writer of a
Hive's row (see `protocol/apiculturist-workflow.md`).

**Opt-out short-circuit (check this FIRST).** Read `hive.yml.federation` (both keys default `true`).
An opted-out Hive is behaving correctly, so its state must never be reported as drift:

- Both `register` and `cross_hive_routing` are `false` ⇒ report `SKIP — federation disabled by
  hive.yml.federation` and run no further checks. Do not contact Confluence.
- `register: false` ⇒ do **not** run check 1 (row presence) or check 3 (metadata drift); a missing row
  is the *intended* state. Instead, if a row for this Hive **does** exist, report:
  `INFO — row present in the registry but federation.register is false. The Apiculturist will not
  maintain or remove it; delete the row by hand if retraction was intended.` This is the one case where
  audit surfaces something a Parliament run will not fix, because retraction is deliberately manual.
- `cross_hive_routing: false` ⇒ do **not** run check 4 (sibling cache freshness); the roster has no
  consumer and is expected to be stale or empty.

**Pre-federation short-circuit.** If `hive.yml.confluence_registry` is absent, report:

> `FAIL` — Hive predates registry federation (`upstream_version {V}`); the Apiculturist cannot see it.
> Run `/apiary upgrade` to backfill `confluence_registry` + `purpose` (`mode-upgrade.md`, pre-2.5.0
> migration).

Skip the remaining checks — there is nothing to compare against.

Otherwise read the page (`confluence edit {REGISTRY_PAGE_ID}`, a READ op) and check:

1. **Row present.** No row matching `hive_slug` ⇒ `FAIL` ("not registered — the next Parliament run
   will insert it").
2. **`Apiary ver` matches `hive.yml.upstream_version`.** Mismatch ⇒ `WARN` with both values. This is
   the most common drift by far: `upgrade` bumps `hive.yml`, and only the next Parliament reconciles
   the row.
3. **Metadata matches.** Compare the row's `Purpose` / `Repository` / `Max Classification` / `Owners` /
   `Slack` against `hive.yml`. Each mismatch ⇒ `WARN` naming the field and both values. A
   `Max Classification` mismatch is a **`FAIL`**, not a `WARN` — the ceiling that other Hives'
   classification direction guard trusts is wrong, which is a security-relevant inconsistency rather
   than cosmetic drift.
4. **Sibling cache freshness.** Compare `len(hive.yml.siblings)` against (registry rows − 1). A
   shortfall ⇒ `WARN` ("roster cached at N, registry has M — operate-mode's cross-hive advisory is
   working from a stale roster"). An empty `siblings: []` on a Hive that has never run Parliament ⇒
   `INFO`, not `WARN`; it self-heals on the first run.

**If the read fails** (Confluence unavailable / unauthenticated): report `SKIP (<reason>)`. Never fail
the audit on registry reachability.

### Step 5: Extension Validity

If any `extensions` values in `hive.yml` are non-null:
- Check that the declared path exists
- Check that the file(s) at the path are well-formed (valid YAML/markdown)
- Report any broken references

For `extensions.workflows`, check each `*.md` at the declared path against the contract in
`references/authoring-workflow-extensions.md`:

| Check | Severity if failed |
|---|---|
| Frontmatter validates against `assets/workflow-extension.schema.json` | ERROR |
| `workflow:` value matches the filename stem | WARN |
| `workflow:` value does not collide with an upstream workflow name | ERROR (upstream wins; the extension is dead code) |
| No two extensions declare the same `workflow:` value | ERROR |
| Exactly one `## Dispatch Table Addition` section, containing at least one row | ERROR (no row = never dispatched) |
| A disambiguation paragraph is present (names the upstream workflow it could be confused with) | WARN (mis-routing risk) |
| Every `delegates_to:` path exists under `knowledge/` | WARN (broken delegation — mechanics unreachable) |
| File is under the 300-line PROTOCOL budget (`design-goals.md` § 6) | WARN (likely carrying mechanics that belong in `knowledge/`) |

A file at the declared path without `type: workflow-extension` frontmatter is flagged
`WARN: not a workflow-extension — silently ignored by operate mode's Merge Extensions step`.

For `extensions.gates`, check each `*.md` at the declared path against the contract in
`references/authoring-gate-extensions.md`:

| Check | Severity if failed |
|---|---|
| Frontmatter validates against `assets/gate-extension.schema.json` | ERROR |
| `gate:` value matches the filename stem | WARN |
| No two extensions declare the same `gate:` value | ERROR (ambiguous reporting) |
| The executable named by the first word of `command:` resolves under the Hive root, or is on PATH | ERROR (gate cannot run; fails closed on every push) |
| `on_error: warn` is accompanied by a stated rationale in `description` or the body | WARN (a fail-open security control needs a reason) |
| `timeout_seconds` is non-zero when the gate's body or command indicates a network/model call | WARN (a hung dependency wedges every contributor's push) |
| Every `required_tools` entry is on PATH in this session | WARN only (the auditor's machine is not the contributor's — report, don't fail) |

A file at the declared path without `type: gate-extension` frontmatter is flagged
`WARN: not a gate-extension — silently ignored by the hook generator`.

Also check, independent of whether `extensions.gates` is set:

| Check | Severity if failed |
|---|---|
| `.githooks/pre-push` exists | ERROR (no push-time enforcement) |
| `.githooks/pre-push` contains the generator's marker (resolve it with `bash {APIARY_ROOT}/skills/apiary/assets/generate-hook.sh --print-marker`, then `grep -qF`; never hardcode the string here) | WARN: `foreign pre-push hook — frozen against upstream pattern updates; migrate its checks to extensions.gates (references/authoring-gate-extensions.md § Migrating a hand-rolled hook)` |
| `git config core.hooksPath` resolves to the Hive root's hooks dir — PASS iff the value equals the **absolute** `{HIVE_ROOT}/.githooks` (what Step 0 writes since 2.23.0). A **relative** `.githooks` is ERROR under `inbox_transport: branch` ("queue-worktree pushes run NO pre-push hook — Layer 0 bypass; re-run operate Step 0 to upgrade to the absolute path") and WARN under `default-branch` ("works from the clone root today, but silently skips the hook on any worktree push and breaks on a transport flip — re-run Step 0"). Any other value, or unset | ERROR (hook present but not active) |
| A gate directory exists on disk but `extensions.gates` is null | WARN (orphaned gates — declared nowhere, so never baked into the hook) |

The last row is the Goal 9 discoverability guarantee for this surface: a gate that
is not reachable from `hive.yml` is dead weight that looks like protection.

### Step 6: Sentinel Retrospective

Check `_inbox/_quarantine/` for items:
- Count quarantined files
- If any exist, list them with Sentinel report summaries
- Flag items older than 7 days that haven't been addressed by a CODEOWNER

### Source Index Integrity (Goal 9)

Sources are discoverable through **either** the manifest (`sources/index.md`) **or** a citation from a `knowledge/**` or `_inbox/**` file's `sources:`/`source:` frontmatter. A source is an orphan only if *neither* references it. This dual rule avoids false positives on binaries ingested by `/extract:ingest`, which become discoverable via their distilled inbox/knowledge citation rather than a manual index row.

1. **Orphaned sources:** List every source file under `sources/` (any doc-type subdir; exclude `index.md`). For each, check whether it is referenced by (a) a row in `sources/index.md`, OR (b) a `sources:`/`source:` frontmatter field in any `_inbox/*.md` or `knowledge/**/*.md` file. Flag those referenced by **neither** as `WARN: orphaned source — not in index and not cited by any knowledge/inbox entry; invisible to Ask`.
2. **Stale index rows:** For each row in `sources/index.md`, verify the referenced file exists. Flag missing files as `WARN: stale index entry — source file missing`.
3. **Missing manifest:** If `sources/` contains any source files but there is no `sources/index.md`, flag as `WARN: no source manifest — native-deposited sources are invisible to Ask` (only WARN, not ERROR: extract-ingested binaries may still be discoverable via citation).

Severity:
- Orphaned sources = WARN (discoverability gap)
- Stale rows = WARN (cosmetic, no data loss)
- Missing manifest = WARN

For an LFS-tracked binary, the audit checks the pointer/path, not the file content (content lives in LFS). Do not attempt to open binary sources during audit.

### Step 7: Generate Report

Write report to `_custodian/reports/YYYY-MM-DD-audit-report.md`:

```markdown
---
type: audit-report
date: {DATE}
upstream_version: {VERSION}
hive: {HIVE_SLUG}
---

# Audit Report — {HIVE_NAME}

## Summary
- Structural: {PASS/FAIL} ({N} issues)
- Catalogs: {N} index files checked, {N} warnings, {N} missing a store root
- Catalog staleness: {N} of {N} catalogs trail their re-trawl threshold; {N} search-promoted rows awaiting placement review
- Freshness: {N} stale / {N} total knowledge files
- Learning Loops: A/Correction={status} B/Discovery={status} C/Calibration={status} D/Escalation={status}
- Routing coverage: {N} uncovered / {N} directory-pointer-only / {N} total knowledge files
- Fast-path share: {N}% measured vs ~80% predicted ({PASS/WARN})
- Push Mode: transport={default-branch|branch(queue={INBOX_BRANCH}, depth {N})} inbox={resolved|n/a} parliament={resolved}, branch={protected|unprotected|unknown} ({PASS/WARN/FAIL})
- Version: {current|behind}
- Registry: row {present|missing|opted out} / ver {match|A vs B} / siblings {N of M} ({PASS/WARN/FAIL/SKIP})
- Extensions: {valid|N issues}
- Quarantine: {N} items pending review

## Details

### Structural Issues
{list or "None"}

### Stale Knowledge Files
{table: file | last_updated | decay | days_stale}

### Stale Catalogs
{table of `type: index` catalogs trailing their re-trawl threshold: catalog | last_updated | days_old | store | discovered_via:search row count — or "None"; each is a re-trawl recommendation, not a defect}

### Push Mode
{resolved transport and inbox/parliament modes, branch protection state, queue depth/oldest-entry age when transport is `branch`, and any FAIL/WARN/INFO from Step 4b — including whether per-flow overrides were offered and the user's response}

### Registry Reconciliation
{Step 4c results: row presence, Apiary ver comparison, per-field metadata drift, sibling cache freshness. If the Hive has opted out via `federation`, say which switches are off and which checks were therefore skipped. If the Hive predates federation, the /apiary upgrade backfill recommendation instead.}

### Learning Loop Issues
{details}

### Quarantine Items
{list with Sentinel report summaries}

## Recommendations
{prioritized action items}
```

Commit the report to the repo.
