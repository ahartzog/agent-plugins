# Inbox Queue-Branch Transport — Design

Implemented protocol as of 2.23.0 (`hive.yml.inbox_transport: branch` — scaffolded default for
new Hives; opt-in for existing ones, whose absent field keeps the legacy transport). Companion to
`protocol/operational-model.md` (the three-phase loop), `protocol/security-policy.md`
(§ Repository Protection Model), and `protocol/custodian-workflow.md` (§1 collect, §6 cleanup).
Loaded on demand — when flipping a Hive to the branch transport, or when asking why it works this
way.

Resolves `BACKLOG.md` § Held → "Inbox transport redesign (queue branch)" (approved 2026-08-03).
The mechanical claims in this document — worktree behavior under a sparse+shallow clone, hook
resolution, the lock ref's atomicity, deletion racing an in-flight push — were verified against
live git before being written down, and are pinned by `tests/clone-flow.test.sh` § transport=branch.

---

## The problem

GitHub's protection primitives are **branch-scoped**. Apiary's write policy is **path-scoped**:
anyone may push `_inbox/**` (capture must be frictionless — Goal 5), everything else is reviewed
(curation must be gated — Goal 4). No ruleset expresses one in terms of the other.

The existing answer wedges the path policy into branch-scoped tooling: `push_mode: pr` with
policy-bot auto-approval, a CODEOWNERS file deliberately narrowed so `_inbox/` is unowned, owners-bot
flags, and repo-level auto-merge — a six-step operator setup (`references/push-mode-pr-setup.md`)
whose failure mode is silent enough that audit Step 4b exists solely to detect it. And it buys the
wrong guarantee even when it works: **unreviewed content still enters the default branch's permanent
history.** A Sentinel-missed credential lives in `master` history even after quarantine moves the
file; remediation is `git filter-repo` on the branch every clone is based on, coordinated across
every clone-holder.

Both problems have the same root: the unreviewed surface and the reviewed surface share a branch.

## The design

Give the unreviewed surface its own branch, and the problem dissolves rather than being worked
around:

- **A single long-lived queue branch** (default name `inbox`, configurable via
  `hive.yml.inbox_branch`) receives all session inbox pushes. It is **never PR-gated**. Its history
  is rooted in an **orphan commit** — it shares no history with the default branch.
- **The default branch gets full vanilla protection**: require a PR + codeowner review for
  everything. No policy-bot, no CODEOWNERS narrowing, no path rulesets, no bots. The protection a
  first-week GitHub admin can configure and any auditor can read.
- **Parliament is the only bridge.** It materializes queue entries into its pipeline, lands curated
  `knowledge/` changes and `_inbox/_completed/` records on the default branch via its normal PR,
  then deletes the processed files from the queue with an ordinary pathspec-limited commit.

```
  sessions ──push──► inbox (queue branch, unprotected, orphan history)
                        │
                        ▼  Parliament (the only bridge)
                   materialize → Sentinel → triage → tribunal
                        │
                        ▼
                   parliament/* branch ──PR + review──► master (fully protected)
                        │
                        ▼
                   queue delete (ordinary commit, pathspec-limited)
```

Two security properties fall out, and they are part of the contract — stated with their exact
boundaries, because an overclaimed security property is worse than none:

1. **Unreviewed content never enters default-branch history *directly*.** Everything on `master`
   arrived through a reviewed PR. While a contribution is **pending or quarantined**, its raw
   bytes exist only in queue history (quarantine records are redacted copies) — so a
   Sentinel-missed secret caught at any point before incorporation never touches master history,
   and there is nothing to purge from the branch everyone bases work on. The boundary: once
   Parliament processes a contribution, its verbatim content reaches master inside the merged
   `_inbox/_completed/` record, through the reviewed housekeeping PR — which makes that review
   the last human gate before session bytes become permanent master history
   (`security-policy.md` § Transport = branch variant states this for reviewers).
2. **Queue history is cheaply rewritable for incident response.** Nothing bases durable work on
   queue history: sessions append files to the tip, Parliament reads the tip, and attribution is
   copied into `_inbox/_completed/` records *before* deletion (§ Attribution, below). Re-rooting
   the queue — a fresh orphan history carrying the surviving pending files, force-with-lease
   pushed — destroys no information anyone needs, **provided the write path's re-root guard is in
   place** (§ How a session writes the queue): without it, a returning old-tip worktree's rebase
   would replay the purged history back onto the new root. Routine processing deletes via
   ordinary commits, so queue *history* grows for the life of the branch (bounded by inbox
   traffic; a re-root resets it) — **rewrite is incident-only.**

The transport is **the recommended default for new Hives** (create mode scaffolds
`inbox_transport: branch`) and **strictly opt-in for existing ones**: an absent `hive.yml` field
means `default-branch`, the pre-2.23.0 behavior, byte for byte. That split is deliberate, not
hedging — flipping the absent-field semantics instead would be a flag day for every running Hive
(each would silently change push targets, lock mechanics, and protection assumptions on its next
session), which is exactly the class of remote-triggered behavior change the coexistence-window
migration exists to avoid. Existing Hives are invited, not moved: audit Step 4b offers the
migration as an INFO recommendation, and a codeowner executes it via `mode-upgrade.md` § 2.23.0.
The transport changes where inbox commits go — nothing about entry format, triage, deliberation,
or the knowledge layer.

## Rejected alternatives

- **Keep everything on master with more policy-bot** (status quo `pr` mode). The complexity being
  escaped is the proposal; and it cannot deliver property 1 at any complexity level, because the
  unreviewed bytes still land in master history before anyone looks at them.
- **A separate inbox *repo*.** Same isolation, plus a second remote to provision, authenticate,
  clone, and permission — doubling the onboarding ceremony that is already the funnel's worst leak.
  A branch is a repo-shaped boundary that costs nothing to provision.
- **Per-contribution `inbox/*` branches only.** Branch proliferation (one per session-push),
  garbage-collection duty, and Parliament must enumerate refs instead of reading one tree. The
  single queue branch subsumes it: one ref, same protection story, same concurrency story.
- **Server-side path enforcement (GHE pre-receive).** GHE-only, needs server admin, and ships
  nothing client-side — it is the Layer-2 backstop in `security-policy.md`, not a transport.
- **Writing the queue via the hosting API** (`gh api` blob/tree/commit, or GitHub Issues). Any
  server-side write path **skips the client-side pre-push Sentinel hook** — Layer 0 simply never
  runs. That is disqualifying for the default transport. (GitHub Issues as a *second*, zero-clone
  transport with its own pre-submission scan story is an explicit follow-on, out of scope here.)

---

## How a session writes the queue

**Decision: a persistent linked worktree at `{HIVE_ROOT}/.inbox-worktree`, checked out to a local
`{INBOX_BRANCH}` branch tracking `origin/{INBOX_BRANCH}`.** The session's working clone stays on the
default branch throughout — the branch-normalize invariant and Orphaned Branch Recovery are
untouched.

The write flow (full script: `mode-operate.md` § Push Procedure):

1. Ensure the queue's tracking refspec is registered, once:
   `git config --add remote.origin.fetch "+refs/heads/{INBOX_BRANCH}:refs/remotes/origin/{INBOX_BRANCH}"`.
   The Step 0 clone is `--depth 1` and therefore **single-branch** — without this, no fetch ever
   creates `origin/{INBOX_BRANCH}` and `--track` refuses the branch. (Verified: both failures
   reproduce exactly on a fresh Step 0-shaped clone.)
2. Bootstrap the queue if the remote branch does not exist: build an empty **orphan** root with
   plumbing (`git hash-object -t tree /dev/null` → `git commit-tree` with no parent) and push it.
   Racing bootstrappers are safe: the loser's push is rejected non-fast-forward and it proceeds
   against the winner's root. A bootstrap rejection is **never swallowed silently** — the one
   non-race cause is a git refname conflict with legacy pr-mode `inbox/*` branches, which HALTs
   with an explicit remedy (verified: any `inbox/…` branch on the remote blocks creating `inbox`).
3. Create (or reattach) the worktree: `git worktree add --track -b {INBOX_BRANCH} .inbox-worktree
   origin/{INBOX_BRANCH}`, then `sparse-checkout disable` inside it — the main clone's no-cone
   sparse patterns are repo-shared and must not filter the worktree's checkout. The queue tree
   holds only pending `_inbox/` files, so a full checkout is a handful of small files.
4. Write the session's inbox file **in the worktree's** `_inbox/`, stage **only the conforming
   shape** (`git add _inbox/*.md` — the staged surface equals the surface Sentinel scans and
   Parliament drains), commit, and push — with the same fetch → rebase → retry guard the default
   transport uses. Unique filenames (`YYYY-MM-DD-<author>-<topic>.md`) mean the rebase is
   structurally conflict-free, exactly as today. **The rebase-retry race story is unchanged; only
   the ref it targets changed.** One addition the legacy flow never needed — the **re-root
   guard**: before rebasing, check for a merge base with the fetched queue tip. None means the
   queue was re-rooted for incident response; a plain rebase would replay the *entire* old
   history (purged content included) back onto the new root — verified live, the purge silently
   undone. Instead, replay only this machine's not-yet-pushed range, bounded by
   `refs/hive/inbox-last-push` — a local ref the block updates **only on a successful push**
   (advancing it past an unpushed tip would make the guard silently drop this machine's own
   entries after a re-root — the dual failure mode, also verified live). The boundary is
   deliberately **not** the remote-tracking ref: Step 0 (or the block's own earlier fetch) may
   already have moved `origin/{INBOX_BRANCH}` to the new root before the boundary is read, and
   `rebase --onto` an unrelated boundary replays the whole old history. And the range is only
   replayed if it is **verifiably this machine's own work** — every commit authored by the
   boundary commit's author and touching only top-level `_inbox/*.md`; a retry rebase during a
   failed-push outage can fold *foreign* commits (another session's Sentinel-missed leak) into
   the local branch, and replaying those would resurrect exactly what the re-root purged. With
   no usable boundary, or a non-own range, the block HALTs into worktree recovery rather than
   rebase blind. Test scenarios B5 and B5b pin the resurrection case and the
   foreign-commit/failed-push case respectively; everything at or below the last pushed tip
   either survived into the new root or was deliberately removed, and neither may be re-pushed
   from here.
   Every command the block runs is covered by the child settings template's allowlist, so a queue
   push adds **zero** permission prompts over the legacy flow (Goal 5).

### Why not plumbing-only pushes (no worktree)

Building the commit with `read-tree`/`update-index --cacheinfo`/`write-tree`/`commit-tree` and
pushing `SHA:refs/heads/inbox` from the main clone works and keeps zero extra state. It was rejected
on a Layer-0 ground: the generated pre-push hook resolves its diff base as *branch upstream →
`origin/<default_branch>` → `origin/HEAD` → empty tree* (the 2.16.1 resolution order). A raw-SHA
push has no upstream, and the queue's orphan history has no merge base with the default branch — so
every push falls through to the **empty tree** and re-scans every pending file on the queue. For the
pattern scan that is noise; for gate extensions it is wrong (a gate asserting a per-contribution
property would demand it of other people's pending entries — the exact defect 2.16.1 fixed). The
worktree's tracked branch gives the hook its correct base (`origin/{INBOX_BRANCH}`) for free, with
no hook changes. Layer 0 stays byte-identical.

### Why not a second clone (the `.parliament` pattern)

A `--single-branch` clone of the queue at `.inbox-clone` is porcelain-simple, but it has its own
`.git` and therefore its **own hook installation** — a second Sentinel lifecycle that Step 0 does
not refresh. A queue clone whose hook predates a pattern update is a silent Layer-0 downgrade on
the one surface that carries unreviewed content. The worktree shares the main clone's repo, so the
single hook Step 0 regenerates every session governs both push paths. One hook, one lifecycle.

### The hook-resolution requirement this imposes

`core.hooksPath` was configured as the relative path `.githooks`. Git resolves a relative
`core.hooksPath` against the **current worktree**, and the queue's checkout does not contain
`.githooks/` — so a push from the worktree runs **no pre-push hook at all**. Verified live: with the
relative path, the hook silently did not fire; with an absolute path it fired from the worktree.
Step 0 therefore now sets `core.hooksPath` to the **absolute** `$HIVE_ROOT/.githooks` (correct and
behavior-identical for both transports — the clone's location is fixed per-user state). This is the
single Step 0 change the transport requires beyond the optional dual-ref fetch.

**Known limitation — gate extensions' working directory.** Under the branch transport, gates baked
into the hook execute with the worktree as cwd, where `PROTOCOL/` and `knowledge/` are not checked
out. A gate whose `command:` resolves its executable via a repo-relative path, or that reads Hive
files at runtime, will not find them on queue pushes. Gates should resolve tools via PATH or
absolute paths; `references/authoring-gate-extensions.md` § Working directory carries the caveat.
The built-in pattern scan is self-contained and unaffected.

### Self-healing states

- **Worktree directory missing, local branch exists** (crash between branch creation and use):
  reattach with `git worktree prune` + `git worktree add .inbox-worktree {INBOX_BRANCH}`. Unpushed
  commits on the local branch are preserved and depart with the next push's rebase-retry.
- **Worktree directory exists but is not a functional worktree**: salvage any `_inbox/*.md` inside
  it to a temp location, `git worktree remove --force` + `prune`, re-create, restore the salvaged
  files, commit, push. No work is silently lost — the Scenario-3 ethic applied to the queue.
- **Stray uncommitted `_inbox/*.md` in a healthy worktree** (a prior session crashed before
  committing): commit and push them along with the current session's entry. The pre-push hook
  re-gates everything in the push, so a file a previous session abandoned at a Sentinel block is
  re-blocked, not smuggled.
- The worktree lives inside `{HIVE_ROOT}`, so the existing "persistent per-user state — never
  auto-delete" rule covers it. The child `.gitignore` gains `.inbox-worktree/` (and `.parliament/`)
  so recovery paths that stage broadly (`git add -A` in Orphaned Branch Recovery) cannot
  accidentally record a gitlink.

## How Ask and Status read pending entries

**Decision: read the remote tracking ref directly; never require the worktree for reads.**

- Step 0, under the branch transport only, fetches the queue ref alongside the default branch —
  as a **separate, tolerant fetch**, because a combined
  `git fetch origin {DEFAULT_BRANCH} {INBOX_BRANCH}` fails *entirely* when the queue does not
  exist yet (verified), which would turn "no session has pushed yet" into a sync HALT. A failed
  queue fetch distinguishes two states rather than conflating them: no cached ref →
  `INBOX_QUEUE_ABSENT` (nobody has pushed); cached ref present → `INBOX_QUEUE_STALE` (offline —
  Status answers from the last-synced snapshot and says so, instead of reporting an empty queue).
- Pending list: `git ls-tree -r --name-only origin/{INBOX_BRANCH} -- _inbox/`.
- Entry content: `git show origin/{INBOX_BRANCH}:_inbox/<file>`. (Under `--filter=blob:none` this
  lazily fetches the blob — a network dependency Status already has, having just fetched.)
- If the local worktree exists, its `_inbox/*.md` files are also checked — they are this machine's
  not-yet-pushed work, the exact "fresher than knowledge" material Status exists to surface.
- During the migration coexistence window, legacy pending entries still live in the clone's own
  `_inbox/` on the default branch; Status checks both surfaces (workflows.md § Status).

The worktree is created lazily by the first *write*; read-only sessions never pay for it.

## Interaction with `push_mode` / `inbox_push_mode`

**Transport is resolved first, and under `branch` it makes the inbox push modes moot.** The entire
purpose of `inbox_push_mode: pr` was navigating default-branch protection for inbox writes; the
queue branch is never PR-gated, so there is nothing to navigate.

Resolution order (mode-operate § Push Procedure):

1. `inbox_transport: branch` → inbox entries push **direct to `{INBOX_BRANCH}`**, always.
   `inbox_push_mode` (and `push_mode`'s inbox half) are **ignored**; audit flags them as dead
   config if set.
2. `inbox_transport: default-branch` (default) → the existing resolution, unchanged:
   `inbox_push_mode` → `push_mode` → `direct`.

`parliament_push_mode` remains fully meaningful under both transports — and under the branch
transport with a protected default branch it must resolve to `pr`, because a direct housekeeping
push to `master` is exactly what the protection now rejects. Audit enforces the pairing (below).
`sources_push_mode` is untouched: `sources/**` stays on the default-branch flow this change does
not cover (a Hive protecting `master` fully must route Deposits via `sources_push_mode: pr`; the
audit note names this).

**Audit becomes transport-aware in two places.** Step 4b, under `branch`, checks in place of the
inbox-side protection checks: the queue branch is not PR-gated by either legacy protection *or*
rulesets — the legacy endpoint cannot see ruleset-imposed PR requirements (FAIL — capture is
wedged); resolved parliament mode is `pr` when the default branch is protected (FAIL otherwise —
housekeeping cannot land); leftover legacy pr-mode apparatus — policy-bot required check,
inbox-only `.policy.yml` rule, ownerless `_inbox/` CODEOWNERS line (FAIL — inbox-only PRs could
merge unreviewed, voiding property 1); a `{INBOX_BRANCH}/*` refname conflict blocking bootstrap
(FAIL); `inbox_push_mode` set (WARN — dead config, downgraded to INFO during a migration
window where it is the documented straggler net); default branch unprotected (WARN — transport
works, but the no-unreviewed-history guarantee is not repo-enforced); queue deletion/force-push
ruleset present (INFO if absent); queue depth, oldest-entry age, non-conforming paths, and
dead `parliament/*` branches (INFO/WARN — the drain-cadence and hygiene signals). Under
`default-branch`, Step 4b gains two additions: the mirror check — `direct` inbox mode on a
*protected* branch is a FAIL (capture wedged — the state a mis-ordered rollback produces) — and
an INFO that **offers the queue-transport migration** (the recommended transport; new Hives are
scaffolded with it), evaluated before the per-flow-override INFO so audit never recommends
config its own next run would flag as dead. **Step 5's hooksPath row**
changes with the absolute-path fix: PASS is now the absolute `{HIVE_ROOT}/.githooks`; a relative
`.githooks` — the pre-2.23.0 value — is ERROR under `branch` (queue pushes run no hook) and WARN
under `default-branch`.

## The Parliament bridge

The pipeline stays transport-blind by design: **§1 materializes queue entries into the Parliament
clone's `_inbox/` working tree, and every step from the Frontmatter Normalizer through the
Chancellor runs unchanged.** Only collect (§1) and cleanup (§6) know the transport exists.

- **Clone setup (§0.5):** the fresh Parliament clone additionally fetches the queue ref, unshallow
  (`git fetch origin +refs/heads/{INBOX_BRANCH}:refs/remotes/origin/{INBOX_BRANCH}`) — queue
  history is short-lived by construction, so "unshallow" is cheap, and per-file attribution needs
  the commits.
- **Collect (§1.3):** copy each `origin/{INBOX_BRANCH}:_inbox/*.md` blob into the working tree,
  recording a **consumption manifest** per file: the last queue commit touching it and its author
  (`git log -1 --format='%H|%an <%ae>|%aI' origin/{INBOX_BRANCH} -- <file>`). Two guards decide
  what enters the work set: a file whose completed/quarantine record is already on the default
  branch is `REDELETE_ONLY` (its only remaining work is deletion); a file whose record sits on a
  **live `parliament/*` branch** — a prior run's still-unmerged housekeeping PR — is
  `PENDING_REVIEW` and skipped entirely (reprocessing it would duplicate deliberation and
  knowledge edits; §0.5 fetches the `parliament/*` refs so this guard can see them). A
  closed-unmerged housekeeping PR whose branch is deleted returns its files to pending — the
  legacy transport's rejection semantics, recovered by construction. §1.3 also runs the **queue
  janitor**: any path not matching the conforming `_inbox/<name>.md` shape was pushed by
  non-Apiary tooling, is outside what the session push stages and the hook scans — it gets
  scanned with the hook's `scan` mode, logged, and drained. Legacy `_inbox/*.md` files already on
  the default branch are collected exactly as today: **the work set is the union**, which is what
  makes migration a coexistence window rather than a flag day.
- **Timeout scanner (§1.2):** evaluated on the materialized copies. `active` files short of the
  timeout are left on the queue untouched (not deleted, not processed) for a later run; the
  status flip is not written back to the queue — the file's next state transition is deletion.
- **Attribution (§6.1):** the reconciliation note written into each `_inbox/_completed/` record
  gains two fields under the branch transport, copied from the consumption manifest **before any
  queue deletion**:

  ```yaml
  queue_commit: <sha of the last queue commit touching the file>
  queue_author: "Name <email>"
  ```

  This is what lets `security-policy.md` § Attribution Chain survive queue truncation: the chain's
  git-blame step is served by the recorded commit + author once queue history is gone. **Ordering
  invariant: a queue file may be deleted only once its `_completed/` record is reachable from
  `origin/{DEFAULT_BRANCH}`** — the housekeeping push landed (`direct` mode) or the housekeeping
  PR **merged** (`pr` mode). Push-durability alone is not enough: an open `parliament/*` branch is
  unprotected and deletable, and closing a housekeeping PR unmerged is a sanctioned codeowner
  rejection — deleting the queue copy against a still-revocable record would let that rejection
  destroy the contribution outright.
- **Queue deletion (§6.3):** drain with `git rm` of exactly the deletable set, one commit,
  ordinary push with the standard fetch → rebase → retry guard. In `pr` mode the invariant means
  a run drains the *previous* cycle's `REDELETE_ONLY` files while its own files wait out their
  review as `PENDING_REVIEW` — the queue lags Parliament by one review cycle, surfaced by audit's
  depth/age INFO. **Pathspec-limited and never forced** — a session pushing mid-run rejects the
  first attempt, the rebase replays the deletions on top of the new entry, and the new entry
  survives (verified live, and pinned by the test suite). If the push still fails after retry:
  log it and leave the queue as-is — the §1.3 guards make the next run's re-encounter harmless.

### The Parliament lock — an atomic lock ref

The queue transport forces the lock question: with a fully protected default branch, §1.1's
committed `.parliament-running` file **cannot be pushed to master at all**, and the `pr`-mode
fallback (existence of a live `parliament/*` branch) is the non-atomic check-then-act the 2026-08
audit flagged — the timestamped branch is not pushed until §6.3, so a second runner sees nothing
for the entire run.

Under the branch transport, the lock is a **fixed-name lock ref**, `refs/heads/parliament/lock`,
using git's own ref-update atomicity as the mutex:

- **Acquire:** build a fresh empty orphan commit (`commit-tree` on the empty tree, message carries
  runner id + UTC timestamp) and `git push origin <sha>:refs/heads/parliament/lock`. Because every
  lock commit is an unrelated orphan, a push when the ref exists is rejected non-fast-forward —
  creation succeeds **iff** the lock is absent. One atomic operation; no check-then-act window.
- **Steal (stale lock):** if the held lock's commit timestamp exceeds `lock_timeout_minutes`,
  replace it with `git push --force-with-lease=refs/heads/parliament/lock:<seen-sha> …` — a
  compare-and-swap that fails if any other runner replaced the lock since it was read.
- **Release:** delete the ref (`git push origin :refs/heads/parliament/lock`) in §6's cleanup.
  A crashed run leaves the ref for the stale-timeout path.

All three operations were verified against a live remote (acquire-blocked-when-held, CAS takeover,
CAS failure on wrong expected sha, release). Legacy transports keep their existing lock mechanics
untouched; unifying them onto the lock ref is attractive but is a behavior change to running Hives
that this opt-in change has no license to make.

## Repository protection model (transport = branch)

`security-policy.md` § Repository Protection Model gains the variant:

| Surface | Ruleset | Contents |
|---|---|---|
| `master` (default branch) | Vanilla branch protection | Require PR + codeowner review for **everything**; block force push + deletion. No policy-bot, no path rulesets, no CODEOWNERS narrowing. |
| `inbox` (queue branch) | "Inbox Queue Safety" branch ruleset | Block **deletion** and **force push** only. No required PRs, no required checks. |
| `parliament/*`, `parliament/lock` | none | Working branches; the lock ref must remain creatable/deletable. |

The queue's deletion/force-push ruleset protects the capture surface from accident, not from
review — an operator must disable it for an incident re-root, the same toggle discipline the
remediation runbooks already use for master.

**Incident response on the queue** (the full procedure lives in `security-policy.md` § Credential
Remediation Runbook, queue-branch addendum): rotate first, as always, and **establish where the
value lives** — if the contribution was already processed, its verbatim `_completed/` record is
on master and the base runbook (filter-repo) applies there too. For the common case — caught
before incorporation, so the secret exists only in queue history — purge by **re-rooting**: build
a fresh orphan history carrying the surviving pending files minus the affected one (replayed as
per-file commits with the original `GIT_AUTHOR_*`, so later attribution capture still names the
contributor, not the operator), force-with-lease it onto `{INBOX_BRANCH}` (ruleset temporarily
disabled). No `filter-repo` on master, no fleet-wide re-clone. Old-tip sessions are handled by
the write path's **re-root guard** — only each machine's own unpushed entries replay onto the new
root. This guard is load-bearing, not an optimization: a plain rebase from an old-tip worktree
replays the whole purged history back onto the queue (verified live — the purge is silently
undone), which is why the guard ships in the same change as the re-root procedure and is pinned
by test scenario B5. Close the incident by adding the missed pattern to
`sentinel-patterns.json` with a positive test.

## Migration (mode-upgrade § 2.23.0)

Opt-in, per-Hive, reversible, no flag day. The authoritative step list (with the pre-flight
refname check, the straggler-extinction gate, the pr-mode teardown, and the rollback ordering)
lives in `mode-upgrade.md` § 2.23.0; the design decisions behind its non-obvious steps:

- **Pre-flight refname check** — legacy pr-mode created `inbox/*` PR branches, and git cannot
  create the ref `inbox` while any `inbox/…` branch exists. Verified: the bootstrap push is
  rejected with a refname conflict. Hence: drain and delete those branches first, or pick a
  non-colliding `inbox_branch`.
- **The protection flip is last, and gated on straggler extinction, not queue health.** Sessions
  on a pre-2.23.0 Apiary cannot see `inbox_transport` at all — they will keep pushing the legacy
  path no matter how fresh `hive.yml` is. A quiet-window check on legacy `_inbox/` commits is the
  gate; and `inbox_push_mode: pr` is set in the same change as the flip as a **straggler net**:
  current clients ignore it under the branch transport, while an old client resolves it and opens
  a visible, reviewable PR instead of having its push invisibly rejected and its contribution
  lost.
- **The legacy pr-mode apparatus must be torn down, not left behind.** The policy-bot
  zero-approval inbox rule and the ownerless `_inbox/` CODEOWNERS line were built to let
  inbox-only PRs merge with no review — under the new "fully protected" master they would keep
  doing exactly that, silently voiding property 1. Audit Step 4b FAILs on leftovers.
- **Rollback order matters:** relax the protection (or stand up the pr-mode apparatus) **before**
  reverting `inbox_transport` — the reverse leaves sessions resolving to a direct push the
  still-protected branch rejects, wedging capture (audit check 1b exists to catch that state).
  Then one Parliament run drains the queue. No knowledge or attribution is destroyed in either
  direction.

## Version: minor (2.23.0), argued

`BACKLOG.md` tagged this item MAJOR ("transport is a schema+behavior change"). The semver policy
(`DESIGN-GOALS.md` principle 8; repo CONTRIBUTING) says major = **breaking** change to the
`hive.yml`/config schema — new *required* fields, renames, migrations existing Hives must run. This
change adds two **optional** fields whose absence reproduces prior behavior byte-for-byte; existing
Hives run unmodified, and the 2.23.0 "migration" is guidance for an opt-in flip, not a required
step. That is the same shape as 2.6.0 (per-flow push modes) and 2.15.0 (gate extensions) — both
minor. The load-bearing counterargument — "a transport is too central for a minor bump" — confuses
importance with breakage; and a major bump has a real cost here: SKILL.md's version check
auto-triggers Upgrade mode on every child Hive at a major mismatch, forcing a no-op migration
ceremony onto ~30 Hives that changed nothing. **Minor.**

## Design Goals compliance

Numbering follows `protocol/design-goals.md` (Goals 1–9), per house precedent
(`external-retrieval-caching-design.md`):

| Goal | Bearing |
|---|---|
| 1 — Reference, don't duplicate | Neutral. No new content surface; the queue holds the same inbox files, elsewhere. The one sanctioned copy — `_completed/` records carrying queue content + attribution — existed under the legacy transport too. |
| 2 — Progressive discovery | Neutral. Routing untouched. |
| 3 — Sensitivity is Hive-local | Neutral by construction: the queue is a branch of the same repo, inside the same protection model; the Sentinel PII/credential scan runs on queue pushes exactly as before (the absolute-hooksPath fix exists precisely so this stays true), and quarantine copies are redacted before they travel to master. |
| 4 — Collective ownership | **Strengthened.** The human gate moves from bot-approximated path rules to native required-review on everything that lands on master — including, explicitly, the `_completed/` diffs in housekeeping PRs (the last gate before session bytes become master history). No gate is bypassed, and the migration tears down the legacy zero-approval machinery rather than leaving it to undermine the new protection. |
| 5 — Contribution flywheel | **Preserved by construction, and audited.** Capture is still one commit+push, direct, no PR, no review; every command in the queue-push blocks is covered by the child settings template's allowlist, so the transport adds zero permission prompts. The worktree is invisible plumbing. The flywheel is not taxed — the queue exists so that *master* can be locked down without touching capture. |
| 6 — Size budgets | Rationale lives here; the hot-path files gain compact rule text only. |
| 7 — Temporal annotations | Neutral. |
| 8 — Upstream governance | Transport mechanics are upstream protocol; only the two `hive.yml` fields are per-Hive. |
| 9 — Discoverability / zero contributor dependencies | bash + git only, as before (repo `DESIGN-GOALS.md` principle 9). The queue is not a new content surface (same `_inbox/` files, same index-less pending semantics as today's `_inbox/`); its observability lives in Status (reads the ref) and audit Step 4b (depth/age/hygiene). |

Repo-level `DESIGN-GOALS.md` principle 10 (operating instructions carry no state or history) is
honored by keeping all rationale in this file; the runbooks carry rules only.

## Open questions

1. **Should the lock ref replace the legacy lock for all transports?** It is strictly more atomic
   than both `.parliament-running` (committed file) and live-branch detection. Deferred: it changes
   behavior for Hives that did not opt into anything.
2. **Queue-side CI.** With capture off master, a checkout-based inbox count sees nothing. The
   scaffolded `inbox-size-check` CI job is transport-aware (it fetches and counts the queue ref
   under `branch`), but it still only *runs* when a PR fires CI — on a quiet repo the queue can
   back up between PRs. Audit Step 4b's depth/age INFO covers that gap for now; a scheduled
   queue check would be the mechanical version.
3. **Should Deposit (`sources/**`) get the same treatment?** A fully protected master forces
   `sources_push_mode: pr`, which taxes a flow that is meant to be direct. A `sources` queue (or
   folding sources into this queue) is a natural follow-on with the same shape — deliberately not
   designed here.
4. **GitHub Issues as the zero-clone second transport** — approved direction, explicit follow-on.
   The Frontmatter Normalizer and `generate-hook.sh scan` were built composable for exactly that
   intake path.
5. **Scheduled queue-history truncation.** Queue history grows monotonically (drains delete
   files, not commits), and Parliament's unshallow fetch pays for it on every run. The re-root
   procedure would serve as a maintenance truncation too — but making rewrite routine dilutes
   "rewrite is incident-only," and the re-root guard makes it *safe* either way. Revisit when a
   busy Hive's queue fetch becomes measurably slow; until then the discipline stays incident-only.
6. **`PENDING_REVIEW` and long-stalled housekeeping PRs.** A housekeeping PR closed unmerged
   whose `parliament/*` branch is *not* deleted leaves its files skipped indefinitely; audit
   reports dead parliament branches, but the recovery (delete the branch) is manual. Automating
   PR-state awareness would need `gh` in the §1.3 path — deliberately avoided for now. The same
   mechanism has a low-grade abuse angle: `parliament/*` is unprotected, so a writer could push a
   forged branch carrying a `_completed/` record to make Parliament skip a specific pending
   entry. Audit's dead-branch listing surfaces it; a naming/authorship convention for run
   branches would harden it if it ever matters in practice.
