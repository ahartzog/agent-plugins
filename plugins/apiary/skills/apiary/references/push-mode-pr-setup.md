# Push Mode: `pr`

Use this reference when a Hive's resolved push mode is `pr` — set via `hive.yml.push_mode: pr`, or per-flow via `inbox_push_mode: pr` / `parliament_push_mode: pr`. That mode is required when the default branch is protected by required status checks, policy-bot, or any other gate that rejects direct pushes from session agents.

**Per-flow split:** `push_mode` is the baseline for both flows; `inbox_push_mode` and `parliament_push_mode` override it for their respective flows (resolution: specific override → `push_mode` → `direct`). The common configuration is `inbox_push_mode: direct` + `parliament_push_mode: pr` — inbox entries are captured aggressively straight to the default branch (the inbox is a review buffer, not a publishing surface), while `knowledge/` merges stay gated behind a codeowner-reviewed Parliament PR. Only the flow whose resolved mode is `pr` uses the runtime procedures below.

The goal: session agents contribute via short-lived PRs that GHE auto-merges without human intervention for the happy path (inbox-only changes). Protected-path PRs still route through code-owner review.

Covers:
- **Runtime procedures** — how session agents and Parliament push when the resolved push mode for that flow is `pr`. Called from `references/mode-operate.md` (session contribute push, gated on the resolved `inbox_push_mode`) and `protocol/custodian-workflow.md` §6.3 (Parliament housekeeping, gated on the resolved `parliament_push_mode`).
- **One-time operator setup** — repo toggles, policy-bot config, owners-bot flags, CODEOWNERS narrowing.

---

## Runtime Procedure: Session Contribute Push

Referenced from `mode-operate.md` "Push Procedure → PR + auto-merge." Use this block instead of a direct `git push` when the resolved inbox push mode is `pr` (i.e. `hive.yml.inbox_push_mode: pr`, or `push_mode: pr` with no inbox override).

```bash
cd "{HIVE_ROOT}"
INBOX_FILE="_inbox/$(date +%Y-%m-%d)-${GIT_USER}-session-${SESSION_ID}.md"
BRANCH="inbox/$(date +%Y-%m-%d)-${GIT_USER}-${SESSION_ID}"
git checkout -b "$BRANCH"
git add "$INBOX_FILE"
git commit -m "inbox: session ${SESSION_ID} contribution"
git push -u origin "$BRANCH"
gh pr create \
  --base {DEFAULT_BRANCH} --head "$BRANCH" \
  --title "feat: inbox contribution — ${SESSION_ID}" \
  --body "Auto-generated inbox contribution. Policy-bot auto-approves; GHE auto-merges once checks pass."
gh pr merge --auto --squash
```

The PR title uses a conventional-commit prefix so hives running the `corroborate pr` check pass.

**Protected-path caveat:** If the PR touches anything outside `_inbox/`, **do not** call `gh pr merge --auto`. The session should surface the PR URL to the user and let a code-owner handle review.

---

## Runtime Procedure: Parliament Housekeeping

Referenced from `custodian-workflow.md` §6.3. Parliament runs commit to a `parliament/YYYY-MM-DD-HHMM` feature branch and open a single PR carrying all cleanup artifacts (run report, completed-file moves, knowledge updates).

```bash
git add _custodian/reports/   # run report + loop-c-counters.json + loop-d-disputes.json
git add _metrics/
git add _inbox/_completed/ knowledge/
git commit -m "chore: parliament run YYYY-MM-DD — {N} contributions merged"
git push -u origin parliament/YYYY-MM-DD-HHMM
gh pr create \
  --base {DEFAULT_BRANCH} --head parliament/YYYY-MM-DD-HHMM \
  --title "chore: parliament run YYYY-MM-DD — {N} contribution(s) merged" \
  --body "Parliament run report attached. See _custodian/reports/ for details."
gh pr merge --auto --squash
```

Parliament PRs touch `knowledge/`, so policy-bot requires a code-owner approval before auto-merge completes — by design. Auto-merge is still requested so the PR merges itself the moment review lands.

The lock, if any, lived on the Parliament branch and is deleted along with the branch after merge. In `pr` mode there is no committed `.parliament-running` file on `{DEFAULT_BRANCH}` — concurrent-run detection relies on the existence of a live `parliament/*` branch on the remote.

---

## One-Time Operator Setup

The rest of this document describes the one-time repo configuration a Hive operator performs before setting `push_mode: pr` in `hive.yml`.

### Path disposition

Decide which paths are "protected" (require human review) and which auto-merge. The conventional split:

| Path | Disposition |
|---|---|
| `_inbox/**` | Auto-merge — Parliament reviews later |
| `_inbox/_completed/**`, `_inbox/_quarantine/**` | Auto-merge — Parliament housekeeping |
| `knowledge/**`, `PROTOCOL/**`, `hive.yml`, `CODEOWNERS`, `.circleci/**`, `.policy.yml`, top-level docs | Code-owner review required |

### One-time repo setup

1. **Enable GHE auto-merge on the repo.** Owners-bot does not expose `allow_auto_merge` as a `repos.yml` field, so set it via API:

   ```bash
   gh api repos/{OWNER}/{REPO} --method PATCH \
     --field allow_auto_merge=true \
     --field delete_branch_on_merge=true
   ```

2. **Add a CI config that reports the required status checks.** Required checks vary per org; a Hive-only config typically needs:

   - A stand-in for the org's default code-scan gate (e.g. a `gatekeeper` no-op job). Hives have no executable code so this is a trivial job.
   - An inbox-size check that fails when `_inbox/` exceeds a threshold, forcing a Parliament run before contributions keep stacking up.

3. **Configure policy-bot (`.policy.yml`) to auto-approve inbox-only PRs:**

   ```yaml
   policy:
     approval:
       - or:
           - inbox-only contribution
           - protected file change
   approval_rules:
     - name: inbox-only contribution
       if:
         changed_files:
           paths: ['^_inbox/.*$']
         no_changed_files:
           paths:
             - '^knowledge/.*$'
             - '^PROTOCOL/.*$'
             - '^hive\.yml$'
             - '^CODEOWNERS$'
             - '^\.circleci/.*$'
             - '^\.policy\.yml$'
             - '^README\.md$'
       requires:
         count: 0
     - name: protected file change
       if:
         changed_files:
           paths:
             - '^knowledge/.*$'
             - '^PROTOCOL/.*$'
             - '^hive\.yml$'
             - '^CODEOWNERS$'
             - '^\.circleci/.*$'
             - '^\.policy\.yml$'
             - '^README\.md$'
       requires:
         count: 1
         users: [...]  # hive codeowners
       options:
         allow_contributor: true
         request_review:
           enabled: true
           mode: all-users
   ```

4. **Update owners-bot config (`repos.yml`):**

   - `enable-policy-bot: true`
   - Drop `code-owner-review: true` (GHE's native CODEOWNERS enforcement is all-or-nothing and cannot be path-scoped — policy-bot handles gating instead)
   - `required-approving-review-count: 0` (policy-bot supplies approvals)
   - Add `policy-bot` to `required-status-checks` alongside any CI jobs

5. **Narrow `CODEOWNERS`** so `_inbox/` is unowned:

   ```
   *           @codeowner1 @codeowner2 ...
   _inbox/
   ```

   The blank owner list on a later rule overrides `*` for the matching path. Without this, GHE's native CODEOWNERS check still fires on inbox-only PRs regardless of policy-bot.

6. **Set `push_mode: pr`** in `hive.yml`.

## Verification

Open a throwaway PR that touches only `_inbox/`. It should:

1. Pass all required status checks.
2. Show `policy-bot: All rules are approved` within a minute.
3. Auto-merge without any human click.
4. Delete the branch on merge.

Open a second throwaway PR that also touches a protected path. It should:

1. Pass status checks.
2. Show `policy-bot: 0/1 rules approved` — waiting on the named code-owner.
3. Block merge until a code-owner approves, even though auto-merge is requested.

If both behave as expected, the hive is wired up correctly.

## Known gaps

- **Legacy PRs** opened before `push_mode: pr` was set will not have auto-merge requested on them. A human has to click "Enable auto-merge" on each, or run `gh pr merge <N> --auto --squash` per PR. Only applies once at the cut-over.
- **GHE does not provide an automatic auto-merge enabler.** Every PR must either have auto-merge requested by whoever opens it (session agents do this; `gh pr merge --auto` is the call) or clicked manually. There is no bot that flips this automatically — consider a lightweight webhook if that becomes painful.
