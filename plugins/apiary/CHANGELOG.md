# Changelog

All notable changes to the **apiary** plugin are documented here.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); this plugin uses [Semantic Versioning](https://semver.org/). The version at the top of each release must match `.claude-plugin/plugin.json`. See the repo-level [CONTRIBUTING.md](../../CONTRIBUTING.md) for change and versioning discipline, and this plugin's [CONTRIBUTING.md](CONTRIBUTING.md) for the mandatory scenario verification.

## [3.0.1] — 2026-08-03 — Post-merge review fixes

Independent multi-lens verification of the 3.0.0 commercial-decoupling branch surfaced six
survivors; this release fixes them. No mechanical/behavioral change to any mode, workflow, or
generated artifact — prose, test-guard coverage, and repo hygiene only.

### Fixed
- **False security guarantee in every generated Hive's README.** `readme-template.md` and
  `child-claude-md-template.md` claimed pushes are scanned "unconditionally and cannot be
  disabled" — untrue for a plain clone and for create mode, which installs no hook. Reworded to
  state what actually happens: pushes through the Apiary's own clone (where operate mode Step 0
  installs the hook) are scanned. Also notes gate extensions run only in the pre-push hook path,
  not in Parliament's `scan-dir` re-scan.
- **`decoupling.test.sh`'s `classification` group was blind to the vocabulary it exists to guard
  against** — it matched the literal token `classification` but not `classified`/`classify`,
  and had no term for banner, marking, portion marking, SECRET, NOFORN, Distribution Statement,
  SBU, or `(U)`. Widened to the concept (`classif(y|ied|ication)`, `marking`, `portion.?mark`,
  `banner`, `\bSBU\b`, `NOFORN`, `Distribution Statement`, `\bTOP SECRET\b`, `\bSECRET\b`,
  `\(U\)`), with a new substring-precise `CLASSIFICATION_ALLOW` covering the resulting legitimate
  hits (generic "sensitivity marking" gate-extension language, "Greeting Banner", "classify by
  content", "rotate the secret", etc.).
- **`notifications`/`federation` groups missed removed-code tokens.** Added
  `Signal notification|via Signal|Signal integration` to `notifications`; added
  `REGISTRY_PAGE_ID|\bsibling\b|federat(e|ed|ion)|Registry Reconciliation|cross.?hive` to
  `federation`, with a `FEDERATION_ALLOW` for the resulting "across Hives" / "sibling code repos"
  false positives.
- **`SLACK_ALLOW`'s `Slack message` and `Slack handle` entries were generic enough to
  self-allowlist new prose.** Narrowed to the actual audited call-sites: `Slack message
  timestamp` and `Professional Slack handle`.
- **Ambiguous `DESIGN-GOALS.md` citations** — four sites already said "plugin-root"; three more
  (`CHANGELOG.md`, `README.md`, `references/inbox-transport-design.md` ×2) still said
  "repo-root"/"repo" and pointed at a file that doesn't exist at the repo root. All now agree.
- **`example.sharepoint.us` → `example.sharepoint.com`** across protocol docs, design docs, and
  the golden fixtures/cases/assertion (moved together). `*.sharepoint.us` is the Microsoft 365 US
  Government (GCC High) tenant domain — the wrong host to have written into a decoupling pass
  whose stated purpose was removing organization-specific coupling.
- Added repo-root `docs/` to `.gitignore` — a scratch planning doc at `docs/superpowers/plans/`
  carried the purged vocabulary verbatim and sat one `git add -A` away from shipping; the
  decoupling test guard's `ROOT` cannot reach outside `plugins/apiary`, so this was a structural
  gap, not a discipline one.

## [3.0.0] — 2026-08-03 — Commercial decoupling

Removes three organization-specific couplings — a DoD-style classification model, an internal
Slack notification bot ("Signal"), and a Confluence-backed Hive Mind Registry/federation — plus
the organization's own identifying references, so the plugin ships clean for the public
marketplace. **Breaking:** existing `hive.yml` files carrying any of the removed keys fail schema
validation (`additionalProperties: false`) until those keys are deleted; see § Removed and the PR
body for the deliberate no-migration rationale.

### Removed
- **Classification model.** The `UNCLASSIFIED`/`FOUO`/`CUI` ceiling, `hive.yml.classification`,
  the `classification` frontmatter field on all five entry schemas, Sentinel's
  classification-banner check (and its non-overridable pattern class — every remaining pattern is
  now overridable via `sentinel_override`; credential/PII scanning is otherwise unchanged), the
  GHE pre-receive variants, and the classification remediation runbook. Hives needing a
  sensitivity taxonomy now declare one as a gate extension — see
  `references/authoring-gate-extensions.md`. Design Goal 3 is renamed **"Sensitivity Is
  Hive-Local"**; Goal numbering is unchanged, so every `Goal N` citation elsewhere remains valid.
- **Signal / Slack notifications.** `hive.yml.slack_channel` (previously a **required** field),
  `.signal/config.yml`, Create mode's Signal step, and the `signal-bot` auto-merge mechanism.
  Quarantine and Loop D escalations now surface via `/apiary audit` (Sentinel Retrospective) and
  PR review requests — there is no push notification of any kind.
- **Federation and the Hive Mind Registry.** `hive.yml.siblings`, `federation`,
  `confluence_registry`, the Apiculturist subagent and its Parliament §1.4 dispatch, cross-hive
  suggestions, the classification direction guard, and Audit Step 4c. Removed alongside:
  `tests/apiculturist.test.sh` and `tests/golden/hive.yml.fixture`.
- **The former security "Layer 2"** — a server-side GHE pre-receive hook that existed only to
  enforce the now-removed classification taxonomy — is retired. The defense model drops from four
  layers (one of them always optional) to three: L0 pre-push hook, L1 session-agent redaction, L3
  Parliament Sentinel intake scan. Layer numbering is left as-is (historical) rather than
  renumbered; every remaining Layer-2 cross-reference was updated to retired/past-tense framing
  (`security-policy.md`, `references/inbox-transport-design.md`) — the initial sweep rewrote one of
  two mentions in the latter's "rejected alternatives" bullet and left the other in live present
  tense, closed in final pre-merge review.
- Organization-specific references: Meridian Systems, claude-clams (the org's internal skill
  marketplace), `ghe.meridian.example` / `jira.meridian.example` / `confluence.meridian.example` /
  `docs.meridian.example`, and the `meridian/owners` centrally-provisioned repo-provisioner flow.
- The strings `CUI`, `ITAR`, `FOUO`, and `UNCLASSIFIED` no longer appear anywhere in the plugin
  outside this changelog and `BACKLOG.md` — enforced by `tests/decoupling.test.sh`'s
  `classification` and `org-coupling` groups. Those word-boundary patterns matched the four full
  strings but not the single-letter DoD portion marking `(U)`, which survived on one golden-fixture
  line (`tests/golden/knowledge/ground-segment/document-catalog.md` and the golden case describing
  it) until final pre-merge review found and removed it — neither pattern nor `\bCUI\b`'s neighbor
  markings catch a bare one-letter abbreviation. Repo-root `SECURITY.md` (outside this guard's
  scope — see the `ROOT=` note in `decoupling.test.sh`) separately still advertised a
  classification-banner scan guarantee after that check was removed from `generate-hook.sh`;
  corrected in the same pass.

### Changed
- **External-retrieval caching now defaults to disabled for every Hive, unconditionally.** The
  default was previously gated on a Hive's classification ceiling (`enabled: true` only below
  UNCLASSIFIED with no marking required); with no ceiling left to read, the conservative default
  now applies universally and caching is opt-in via `hive.yml.cache.enabled: true`.
  `external-retrieval-caching-design.md` § Classification is renamed § Exposure to match.
- Parliament's auto-merge post-hoc human gate now rests on PR visibility plus `git revert`, no
  longer on a Signal post — the removed notification's load-bearing justification is rewritten
  rather than left dangling.
- **Ambiguous `Design Goal N` citations disambiguated plugin-wide**, because the repo carries two
  independently-numbered documents by that name. Convention going forward: a bare `Goal N`
  resolves to `protocol/design-goals.md`; a citation of the plugin-root `DESIGN-GOALS.md` is always
  qualified as "principle N" with the file named explicitly. Applied across markdown, `.sh`, and
  `.json` files (an initial `*.md`-only sweep missed two of the latter).
- **`triage-policy.md` and `push-mode-pr-setup.md` no longer reference `corroborate`**, an
  undefined internal CI status check that operators were told was required. Both now point at
  "whatever checks your repo's branch protection actually requires," with
  `assets/circleci-config-template.yml` as the concrete example.
- **The post-create instruction in README.md / `mode-create.md` no longer assumes an internal
  marketplace.** "Register the child skill in your plugin marketplace" (unexplained and
  org-specific) is replaced with a concrete path: create `~/.claude/skills/{HIVE_SLUG}/SKILL.md`
  from the generated skill file's contents to make `/your-hive-slug` callable, with marketplace
  publishing named as the optional team-sharing path.
- **GitHub Enterprise branding genericized on the protection model** (`security-policy.md`,
  `operational-model.md`) while preserving the real constraint: branch protection / rulesets are
  standard GitHub features, not GHE-specific, so the prose no longer implies otherwise.
- `CONTRIBUTING.md`'s schema-change migration rule now covers removed fields as well as added
  ones, and permits a stated skip when no Hive is known to run the prior schema — this release
  exercises that skip (see the PR body).

### Added
- **`tests/decoupling.test.sh`** — a five-group regression guard. `classification`,
  `notifications`, `federation`, and `org-coupling` assert the four removal classes stay removed
  (with a substring-precise allowlist for legitimate look-alike mentions, e.g. the Slack-token
  credential pattern); a fifth group, `survivors`, positively asserts that legitimate content —
  the Sentinel triage runbook's `classify` verb, the `diagnose-and-classify` pointer, the gate
  override mechanism, and the 18-pattern Sentinel count — was not collaterally deleted by the
  sweep.

## [2.24.0] — 2026-08-03

### Added
- **§Match restates the query before scanning triggers.** Triggers are written in the *author's* vocabulary; questions arrive in the *asker's*. Matching raw phrasing against raw triggers is keyword collision — and §Match is the step whose failure is most expensive, because a miss ends the protocol before §Prefer, §Resolve, or §Extract ever run, and it fails **silently** (the output is an ungrounded answer, not an error). Sessions now write 2–4 alternate phrasings on one line — synonyms, document-vocabulary form, entity/acronym names the question implies but does not say — and scan triggers against that set. Explicitly bounded as **restatement, not decomposition**: no sub-questions, no hypothetical-answer generation, no per-phrase retrieval pass; those cost more than the fetch economy returns. One line, one scan.
- **§Answer closes with a one-line routing trace, and every citation must name a locator in its `opened:` list.** The trace carries the restatement, library/match counts, the sufficiency verdict, and what was actually opened. Two rules make it load-bearing rather than decorative: a citation naming nothing in `opened:` is a document that was never read (remove the citation or open the document), and an empty `opened:` means §On no match must have fired. This is the cheapest citation-verifier available — it costs no extra call, since the opened list is already in hand — and it is what makes the protocol observable: golden cases can assert on its structure, and the answered-from-opened ratio is the signal telling Loop B whether routing is improving or decaying. Deliberately one line; it runs on every Ask.
- **§Answer warns the reader when a cited file is past due.** A cited knowledge file past its `review_by`, or whose `last_updated` exceeds its `decay` threshold, is annotated inline on the citation itself — *per `ground-segment/architecture.md` (unverified since 2026-03-04)* — not in a separate caveat paragraph. The warning has to travel with the fact, because the fact is what gets quoted onward. A stale copy read as current is worse than silence (design-goals §1).
- **New optional inline annotation `[effective: YYYY-MM-DD]`** — when a fact became true **in the world**, as distinct from `[learned:]` (when it entered the Hive). The two clocks diverge exactly where it matters: a fact backfilled today about last quarter's decision is the newest by `[learned:]` and the oldest in reality, so ranking on ingestion time returns the wrong answer confidently. §Prefer now ranks status questions on `[effective:]` where present; audit Step 2 decays individual facts from it where present. **Both fall back to the existing clock when it is absent**, so no file becomes invalid, nothing needs backfilling, and adoption is gradual and per-fact. Never inferred — an unstated `[effective:]` is left off, since §Prefer ranks on it mechanically. Mirrored into the Second Brain schema (plugin 2.1.0) under the shared-taxonomy contract.
- **§Prefer gains a freshness tiebreak.** Between otherwise-comparable candidates (same `authority`, both responsive), prefer the healthier `decay`/`review_by` posture. A stale winner still wins, but is caveated per §Answer rather than presented as current.
- **`references/external-retrieval-design.md` § Why there is no vector store, and what would change that** — the no-embeddings choice is now the research-validated *better* architecture at Hive scale (Claude Code's own move from vector search to grep; the agentic-search ablations; ~94.5%-of-RAG at zero infrastructure), not the zero-dependency concession it was originally framed as. The citations are written down so the first "let's add a vector DB" proposal meets them, together with a falsifiable revisit trigger: a single Hive past ~1–2k indexed documents **and** `loop-b-gaps.json` showing misses dominated by paraphrase failures rather than coverage gaps. The second condition is load-bearing — a vector store fixes vocabulary mismatch and does nothing for material that was never indexed.
- **Golden cases 15 and 16** with a real `sources/` fixture tree (manifest, verbatim transcript, and a curated paraphrase that rounds the committed value), plus Part A drift guards binding each new case to the protocol clause it tests. The paraphrase deliberately omits the exact figure, so answering from the wrong file is textually detectable rather than a judgment call. **clone-flow.test.sh gains Scenarios C0 and C1**, which extract `resolve_default_branch()` and the sparse-checkout line from `mode-operate.md` **itself** rather than re-copying them — a copied snippet can pass while the shipped script is broken, which is the exact defect class C0 exists to catch.

### Fixed
- **Step 0's returning-session sync HALTed on every Hive whose remote had advanced** (found by the scenario verification this plugin's CONTRIBUTING mandates, not by the suites). The sync fetch carried `--depth 1` against an already-shallow clone: `fetch --depth 1` **re-shallows to the new tip** rather than extending history toward the local one, so the fetched tip and local HEAD shared no ancestor inside the shallow boundary, `git merge --ff-only` failed with *"refusing to merge unrelated histories"*, and the block HALTed the session reporting **"Likely cause: local commits on {DEFAULT_BRANCH} that were never pushed"** — on a clone that had none, sending the operator into Diverged Default-Branch Recovery and a `reset --hard` to fix nothing. Reproduced at remote-ahead-by-1, 2, and 3 commits: it fired on essentially every returning session, which is CONTRIBUTING's Scenario 2. **Why no suite caught it:** `clone-flow.test.sh`'s `run_step0()` is an *adapted copy* of Step 0, and it fetched without `--depth` — so Scenario 2 passed against the copy while the shipped script failed. Dropping `--depth` from the sync fetch keeps the clone shallow, syncs correctly, and still refuses a genuinely diverged clone (the property the guard exists for — all three now asserted). New **Scenario C2** runs the shipped flags against a real shallow clone and carries a drift guard rejecting any reintroduction of `--depth` on that fetch.
- **The `sources/` read path: the Hive's highest-fidelity material was addressable but unreachable.** `protocol/sources-policy.md` prescribes the router row verbatim as `sources/index.md`, while §Resolve resolved every local Source token relative to `knowledge/` — so the prescribed row became `knowledge/sources/index.md`, which exists in no Hive. Audit Step 1b applied the same rule and independently reported the row as a broken pointer, so the failure was visible as a false positive rather than as the read-path defect it was. §Resolve now carries a **Hive-root locator row** (`sources/…` resolves from the Hive root, falling back to `knowledge/` once before flagging), and Step 1b matches the read path exactly. Existing Hives are repaired without any edit on their side, provided they carry the prescribed router row — `mode-upgrade.md` § 2.24.0 states the one-row action and audit now flags its absence.
- **§Extract falls through to the verbatim original when the wording *is* the answer.** A `knowledge/` file is a curated paraphrase; `sources/` holds the deposited original. On questions asking for exact wording, a committed value, requirement text, or who said what, the paraphrase is no longer quoted as though it were the source — the session checks `sources/index.md` or the answering file's own `sources:` frontmatter, opens the original, and quotes from there. **Where the source and the knowledge file disagree, the source wins**, and the divergence becomes a `[correction]` contribution with the source path as evidence. Ordinary topical questions stay on the `knowledge/` path; the clause fires on the wording, not the topic.
- **Step 0 resolves `{DEFAULT_BRANCH}` itself instead of taking a substituted guess.** The branch-normalize check needs the value *before* the script reaches `cat hive.yml`, so a session that has never read `hive.yml` could only supply the documented default (`master`) — and every Hive with `default_branch: main` therefore false-HALTed a returning session with `HALT_ORPHANED_BRANCH` on a perfectly healthy clone, sending the operator into Orphaned Branch Recovery for a branch that was never orphaned. Resolution now happens in bash, the same way `PERSONA_PATH` already did: `hive.yml` → `refs/remotes/origin/HEAD` (verified to survive `--depth 1 --sparse --filter=blob:none`) → `master`. The resolved value is echoed as `DEFAULT_BRANCH_RESOLVED:` for later steps, and the HALT message now names both branches so recovery has what it needs even though the halt prevented `hive.yml` from being emitted.
- **Step 0's sparse-checkout omitted four paths the session reads or writes, and only ever ran on first clone.** The missing paths: `/CLAUDE.md` and `/README.md` (audit reads both), `_metrics/` (every Ask writes a session log to it), and `.signal/` (audit checks its config). On a clone whose `--no-cone` patterns omit `_metrics/`, `git add _metrics/<file>` fails outright — *"matched paths that exist outside of your sparse-checkout definition"* — so the session log could never be committed. Adding the paths alone would have fixed **new clones only**: `sparse-checkout set` sat inside the fresh-clone `else` arm, and every existing `~/.claude-hive/{slug}` takes the `if [ -d "$HIVE_DIR/.git" ]` arm forever, so it would have kept its original patterns indefinitely. The call is now unconditional (it is idempotent), which is what actually widens existing clones — verified by a returning-session assertion in Scenario C0e, not just by the pattern-list check.
- **Step 0's Identity parse list omitted three groups the same file dispatches on 160 lines later:** the push modes (`push_mode`, `inbox_push_mode`, `parliament_push_mode`, `sources_push_mode` — § Push Procedure resolves `inbox_push_mode` → `push_mode` → `direct`), the `classification` block (`max_level` + `marking_required` — the always-on ceiling invariant cannot be held without it), and the `federation` block (`cross_hive_routing` gates the cross-hive advisory, which otherwise fires on a Hive that opted out).
- **Audit Source Index Integrity gains the read-side gate.** Checks 1–3 verify sources are *indexed*; nothing verified they were *routed to*, so a perfectly maintained `sources/index.md` could still be unreachable from any question. A manifest with no reference-library entry pointing at it is now `WARN: … every deposit is write-only`.

### Changed
- `references/mode-upgrade.md` § 2.24.0 documents the release and states the single optional action (the `sources/index.md` router row) for existing Hives.

## [2.23.0] — 2026-08-03

### Added
- **Inbox queue-branch transport — the recommended default for new Hives:** new optional `hive.yml` fields `inbox_transport: default-branch | branch` and `inbox_branch` (default `inbox`). Create mode and `hive.yml.template` scaffold `inbox_transport: branch` into every new Hive; an **absent field still means `default-branch`**, so existing Hives never change transports on a plugin update (no flag day) — audit Step 4b offers them the migration as an INFO recommendation instead. Under `branch`, sessions push inbox entries to a dedicated, never-PR-gated queue branch via a persistent `.inbox-worktree` (bootstrapped as an orphan root on first push), and the default branch can carry full vanilla protection — required PR + codeowner review on everything, with no policy-bot, path rulesets, or CODEOWNERS narrowing. Parliament is the only bridge: it materializes queue entries into its normal pipeline (§1.3), records `queue_commit` + `queue_author` in each `_inbox/_completed/` reconciliation note **before** any deletion (the attribution chain survives queue truncation), and drains processed entries with an ordinary pathspec-limited commit that never clobbers an in-flight session push. Security contract: unreviewed content never enters default-branch history, and queue history is cheaply rewritable for incident response (re-root runbook added to security-policy). Design doc: `references/inbox-transport-design.md`; migration: `references/mode-upgrade.md` § 2.23.0. Existing Hives are untouched — absent fields reproduce prior behavior exactly.
- **Atomic Parliament lock ref** (queue transport only): `refs/heads/parliament/lock` acquired by an orphan-commit push (create-iff-absent), stolen via `--force-with-lease` CAS on stale timeout, released by ref deletion — replacing the committed lock file, which cannot reach a protected default branch, and fixing the non-atomic `pr`-mode concurrent-run detection for Hives on this transport.
- **Re-root guard on the queue push path** (found by adversarial design review, reproduced live): after an incident re-root, a returning worktree's plain rebase would replay the entire purged history — secret included — back onto the queue. The push block now detects the missing merge base and replays only that machine's not-yet-pushed commits, bounded by a `refs/hive/inbox-last-push` ref recorded **only on push success** (the remote-tracking ref is not a safe boundary — Step 0's fetch may already have moved it to the new root; and a boundary advanced past an unpushed tip would silently drop the machine's own entries — both failure modes reproduced live). The replay additionally requires the range to be verifiably this machine's own work (boundary-author + `_inbox/*.md`-only) — a retry rebase during a failed-push outage can fold a *foreign* session's leak commit into the local branch, and replaying it would resurrect purged content. With no usable boundary or a non-own range it HALTs into worktree recovery rather than rebasing blind, and the block's exit status now honestly reports push failure (`QUEUE_PUSH_FAILED`).
- **Merge-gated queue drain + pending-review guard:** a queue entry is deleted only once its `_inbox/_completed/` record is reachable from the default branch (housekeeping PR *merged*, not merely pushed) — so a codeowner closing a housekeeping PR unmerged returns its files to pending instead of destroying the only copy; §1.3 skips files whose records sit on a live `parliament/*` branch (no duplicate deliberation while a PR waits), and Parliament's clone fetches those refs to see them. A queue janitor scans and drains non-conforming queue paths (outside `_inbox/*.md`) that the session push path never stages.
- **Migration hardening:** pre-flight check for legacy `inbox/*` branch refname conflicts (they block queue bootstrap — the bootstrap failure is now HALT-with-remedy, not swallowed); straggler-extinction gate + `inbox_push_mode: pr` straggler net for pre-2.23.0 clients (their direct pushes would otherwise be invisibly rejected and lost); explicit teardown of the legacy policy-bot / narrowed-CODEOWNERS apparatus (leftovers let inbox-only PRs merge unreviewed, voiding the transport's guarantee); rollback re-ordered (relax protection *before* reverting the transport — the reverse wedges capture). New "Diverged Default-Branch Recovery" salvages committed-but-unpushed inbox work before any `reset --hard`.
- **clone-flow.test.sh gains seven queue-transport scenarios** (B0 Step 0 hive.yml parse against the template's own comment style; B1 first push with orphan bootstrap + hook-fires-from-worktree assertion; B2 returning session; B3 concurrent push race; B4 Parliament consume+drain preserving attribution; B5 re-root guard — purged content must not resurrect; B5b failed-push window — a foreign commit in the replay range HALTs, the boundary never advances on a failed push), and CONTRIBUTING gains Scenario 4 for the transport.
- **Step 0's hive.yml parse strips inline comments and trailing whitespace** for `inbox_transport`/`inbox_branch` (a value like `branch  # comment` previously failed the equality test and silently deactivated the transport); the template ships its transport lines comment-free (active by default — see the Added entry). Parliament's clone registers the queue fetch refspec in §0.5 (a depth-1 clone is single-branch — without it, §6.3's drain retry fetched into the void and rebased against a stale ref), and §1.3's consumption manifest is run-scoped inside the Parliament dir and truncated per run (a shared append-only path could feed stale or cross-Hive attribution into `_completed/` records). The queue-push procedure is restructured into ensure-worktree → write entry → commit+push, so the entry write has a worktree to land in on the very first push.

### Fixed
- **Step 0 now sets `core.hooksPath` as an absolute path.** Git resolves a relative `core.hooksPath` against the *current worktree*, so a push from any linked worktree (the queue transport's push path) would silently run **no pre-push hook** — a Layer 0 bypass. Behavior on the default transport is unchanged; the clone's location is fixed per-user state. Audit Step 5's hooksPath check updated to match (PASS = the absolute path; a legacy relative `.githooks` is now ERROR under the branch transport / WARN otherwise — previously the check would have flagged every healthy Hive and steered operators back to the insecure value).
- **Audit Step 4b gains the mirror failure check:** `direct` inbox mode on a *protected* default branch is a FAIL (capture silently wedged — the state a mis-ordered rollback or premature protection flip produces). Previously only the inverse (`pr` on unprotected) was checked.
- **Security property stated precisely, not overclaimed:** processed contributions' verbatim bytes *do* reach the default branch inside merged `_inbox/_completed/` records — the no-purge guarantee applies to content caught while pending/quarantined. security-policy names the housekeeping-PR review as the last human gate, and the incident runbook now starts by locating the value (master's `_completed/` too, not just the queue) and closes by adding the missed pattern with a positive test. Re-roots preserve contributor authorship on replayed survivors.

### Changed
- Transport-aware surfaces: mode-operate Push Procedure resolves `inbox_transport` before push modes (`inbox_push_mode` is ignored — and audit-flagged as dead config — under `branch`); audit Step 4b runs queue-transport checks (queue never PR-gated by legacy protection *or* rulesets, `parliament_push_mode: pr` required once the default branch is protected, leftover pr-mode apparatus, refname conflicts, queue depth/age/hygiene, dead parliament branches); operational-model's Accumulation phase describes both transports; push-mode-pr-setup marks its inbox half as must-be-torn-down at migration; workflows § Status reads pending entries from the queue ref (with an offline-stale caveat — Step 0 distinguishes `INBOX_QUEUE_STALE` from `ABSENT`); gate-extensions authoring guide documents the worktree working-directory caveat; child settings template allowlists the transport's read/plumbing commands so a queue push adds zero permission prompts; create mode asks Q5.35 (default: `branch`, template-scaffolded; choosing `default-branch` deletes the lines) and ships `.parliament/` + `.inbox-worktree/` in the child `.gitignore`; the default-branch direct-push runbook distinguishes protected-branch rejection (permanent, misconfiguration) from transient push failure.

## [2.22.0] — 2026-08-03

### Added
- **Loop B telemetry** (`_custodian/reports/loop-b-gaps.json`) — the loop that captures user-visible routing failure finally gets the counters Loops C and D already had. §On no match contributions now carry deterministic mining prefixes (`coverage-gap:` / `routing-gap:` / `unreachable:`); Parliament §6.2 rebuilds the deduped 90-day gap backlog idempotently; audit Step 3 reports the top repeated gaps; Brief ranks its "what are we failing to answer" section from the file instead of re-deriving it. Schema in `references/learning-loops-design.md`.
- **Two design docs** (proposals, not yet implemented): `references/merge-disposition-design.md` — a `triage.deliberation_merge: auto | review` knob making the clean-MERGE human gate configurable and wiring it into Loop C as an evidence-based graduation/demotion path; `references/audit-fix-design.md` — the consolidation/"dreaming" pass shaped as `/apiary audit --fix` (audit's findings become the remediation work queue), with the Goal-4 carve-out question stated for decision.

- **CI, two tiers:** `.github/workflows/apiary-tests.yml` runs all seven deterministic suites on every apiary PR (intended required check); `.github/workflows/apiary-golden-behavioral.yml` runs golden Part B with a real headless Claude session (weekly / on demand / maintainer-labeled same-repo PRs; transcripts as artifacts; model pinned via the new `APIARY_GOLDEN_CLAUDE_ARGS` hook in `golden-routing.test.sh`).

### Fixed
- **Test suites are hermetic against user git config:** fixture repos now run with `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM` nulled and a pinned test identity — a globally-installed hook suite (e.g. ggshield via `core.hooksPath`) was intercepting fixture pushes and failing setup for any contributor who has one.

### Changed
- **BACKLOG consolidated into the canonical work ledger:** every open recommendation from the 2026-08 multi-agent audit is now a formal item with provenance and a confidence tag, organized into Held-decisions / Designed / enforcement / retrieval / loops / guardrails / profiles / open-sourcing themes; delivered items marked; the protocol-toggles sketch superseded by the profiles reframe (its Sentinel-disable line contradicted design-goals §4). A clean-slate session can now start from BACKLOG.md alone.
- **Restatement dedup:** workflows §Ask's paragraph-length RLDP summary → one governing pointer; SKILL.md and the Contribute/Parliament/mode-operate cross-hive passages now defer to custodian §2.1 step 5 as the guard's single authoritative statement; custodian §2.1's tag→path table → pointer to triage-policy's canonical category table; mode-operate's Learning Loop Enforcement compressed to the two-line session-side contract. Roughly ~500 tokens off every Ask and ~1k off every Parliament run, and each rule now has exactly one owning surface (the "restated rule will drift" lesson, applied).
## [2.21.0] — 2026-08-03

### Changed
- **Compact RLDP rendering** (`protocol/routing-protocol.md`): the canonical routing file drops from 277 lines (~4.8k tokens) to 189 (~3.3k) — a ~31% cut on the fixed cost of **every Ask** across every Hive — by demoting design rationale to the `references/*-design.md` files where principle 10 says it belongs. Zero normative change: every § step name, every rule, and every sentence the golden suite pins survives verbatim (verified by phrase-level check + full suite + behavioral Part B). New rationale sections in `external-retrieval-design.md`: "Why recency is resolved mechanically" (with the research citation, so the deterministic-sort rule can defend itself) and "Why the sufficiency test sits on the catalog-rows set".

## [2.20.1] — 2026-08-03

### Changed
- Marketplace renamed `ahartzog-skills` → `ahartzog`; install pointers emitted by this plugin updated accordingly (`references/mode-operate.md`, `assets/child-skill-template.md`, `README.md`). No behavior change.

## [2.20.0] — 2026-08-02

Protocol-consistency and deterministic-enforcement release, produced from a deep multi-agent audit (5 analysis lenses + 4 market researchers + adversarial verification) of the 2.19.0 export.

### Fixed
- **Canonical MERGE disposition rule** (custodian §4.3): four surfaces disagreed on whether a Chancellor-approved deliberation contribution auto-merges or waits for CODEOWNER review — the rule that decides whether human review happens. Now stated once (clean MERGE → auto-merge batch; MERGE-with-objection or Loop D fired → needs-review PR); triage-policy and operational-model defer to it.
- **RLDP loads on every Ask** (mode-operate Step 2 said "unless the routing table resolved the question", silently skipping §Search sufficiency and §On no match gap capture).
- Defense layers renumbered to one scheme file-wide (L0 pre-push hook / L1 session redaction / L2 GHE pre-receive [optional] / L3 Parliament Sentinel); FOUO removed as a selectable ceiling everywhere; dangling `docs/…design.md` spec pointers replaced with inline escalation-PR + reconciliation-note templates; step-renumbering drift fixed in 7 files; mode-audit's Loop A check rewritten in Apiary terms (was Second Brain vocabulary that vacuously passed).
- **Sentinel regex bugs:** `\s` inside POSIX bracket expressions (literal backslash — connection-string could never match a password containing "s") and token-literal's `[_\-.]` decreasing-range error, swallowed by stderr redirection, meaning the pattern never matched anything. All patterns rewritten to `[[:space:]]` classes.

### Added
- **Sentinel hardening:** frontmatter scanning (override block excluded); `sources/**.txt` coverage; classification-banner scan baked from `hive.yml.classification.max_level` (banner-shaped only; path references stay sanctioned; `classification.*` never overridable); excerpt-bound `sentinel_override.matches`; 6 new patterns (fine-grained/OAuth GitHub tokens, `xoxe-`, Azure AccountKey + SAS, JWT, Bearer header); quarantine now redacts and the report masks values; Credential Remediation Runbook (rotate first, then purge).
- **Parliament deterministic scan** (custodian §0): the generated hook's `scan-dir` is now a literal runbook command; scan-dir walks `sources/` too.
- **Loops C and D actually fire:** §4.1.05 prior-contradiction check (second challenge in 30 days → `[disputed:]` + needs-review PR); §6.2 writes both telemetry files via an idempotent 30-day-window rebuild; housekeeping stages `_custodian/reports/` + `_metrics/`.
- **Write Operations taxonomy** (triage-policy): tags imply ADD / SUPERSEDE (paired in-place edit) / ANNOTATE; deliberately no DELETE. Reviser emits the paired `[superseded:]` edit.
- **RLDP:** §Recurse boundary defined (first router→catalog hop is §Extract, not a traversal); sufficiency verdict stated in one auditable line; deterministic recency (extract dates, sort, then choose) and one-pass table ranking; §On no match carve-out for local reads and covers-answers; §Answer completion gates; concurrent two-store search dispatch; rarest-term-first catalog grep.
- **Golden suite:** Cases 13 (recency/sufficiency-verdict) and 14 (abstention + gap capture) with Part B judges; five Governing-line quote attributions corrected; Part B timeout portability (macOS). Sentinel suite 23 → 68 assertions incl. a positive test per pattern; sentinel-base 12 → 14 (sources/*.txt pre-push path).
- **README:** dual-audience rewrite — beginner explainer with mermaid architecture/loop/RLDP diagrams, a "Where decisions actually get made" authority ladder, and a dense Protocol Contract for LLMs.

### Verification
All seven suites green (clone-flow 8, apiculturist 29, normalizer, golden Part A 33, gate-extensions 36, sentinel-base 14, sentinel 68); golden Part B behavioral half 7/7 live-agent cases pass, including the new sufficiency-verdict and abstention cases. Changes adversarially reviewed by four independent agents; all confirmed findings fixed.

## [2.19.0] — 2026-08-02

Wholesale import of the current (sanitized) Hive Parent Protocol export, bringing this copy from the 2.4.0 snapshot to the 2.19.0 protocol lineage. Repo identity (plugin name `apiary`, MIT license, this changelog) preserved; all organization-specific references remain fictional placeholders. Highlights of the imported lineage (full detail: `skills/apiary/references/mode-upgrade.md` § Version Notes):

### Added
- **RLDP consolidation (2.12.0):** `protocol/routing-protocol.md` is the canonical, upstream-owned Reference Library Discovery Protocol; personas reference it instead of carrying frozen inline copies. §On no match gap-recording is mandatory.
- **Learning loops named + enforced (2.13.x):** Correction / Discovery / Calibration / Escalation; Loop B binds capture and findability as one obligation; directory pointers are canonical.
- **External retrieval as a first-class routing step (2.16.0):** `Load` split into §Resolve/§Extract; `covers` catalog field; store roots for `type: index` catalogs; Store Kind → Tool table.
- **Gate extensions (2.15.0):** Hive-specific pre-push hardening baked into the generated hook, structurally unable to suppress the Sentinel.
- **Merge-base fix for the pre-push hook (2.16.1)** plus `sentinel-base.test.sh` regression suite.
- **Live store search (2.19.0):** RLDP §Search — miss and augment paths, search subagent contract (`protocol/external-search-agent.md`), promotion-requires-a-read, catalog staleness audit check.
- **Apiculturist registry reconciliation (2.11.0)** and federation opt-outs; per-flow push modes (2.6.0); sources deposit path; golden routing/retrieval test suite (`tests/golden/`).

## [2.4.0] — 2026-06-10

The Hive Parent Protocol at **2.4.0**. Earlier version history predates this repo; tracking starts here.

### Added
- Hive Parent Protocol modes: create / operate / audit / upgrade.
- Parliament triage (inbox → curated knowledge), Sentinel scanning, and custodian health checks.
- Git-backed multi-contributor knowledge bases with a self-healing clone/sync flow (first install, remote-ahead pull, rogue-branch recovery).
