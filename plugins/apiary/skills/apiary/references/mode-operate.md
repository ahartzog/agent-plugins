# Operate Mode — Runtime Execution

This document guides the Operate mode of the Apiary skill. Follow these steps exactly.

## Prerequisites

SKILL.md has already:
- Resolved `{APIARY_ROOT}` from `${CLAUDE_PLUGIN_ROOT}` (used below to locate bundled assets)
- Received identity from the child skill stub (hive_slug, remote, or a hive.yml path)
- OR found `hive.yml` via Hive Discovery (cwd walk)

## Step 0: Startup — Sync, Install Sentinel Hook, Load Identity & Persona in ONE bash call

The Hive clone is **persistent per-user state** at `${HOME}/.claude-hive/{HIVE_SLUG}/`. It holds uncommitted inbox work — never auto-delete.

Run the single script below in one tool call. It does the full git flow (clone-or-pull, branch-normalize, ff-sync), (re)installs the pre-push Sentinel hook, **and** prints `hive.yml` + the persona file in the same tool result — so identity and persona load with zero extra round-trips. Do not split this into multiple tool calls.

```bash
HIVE_DIR="${HOME}/.claude-hive/{HIVE_SLUG}"
mkdir -p "$(dirname "$HIVE_DIR")"

# Resolve the default branch INSIDE the script, the same way PERSONA_PATH already is. The
# branch-normalize check below needs the value before the script reaches `cat hive.yml`, so a
# literal `{DEFAULT_BRANCH}` placeholder can only carry whatever the session guessed — and a
# returning session on a `main`-defaulted Hive guesses `master` (the documented default) and
# false-HALTs with HALT_ORPHANED_BRANCH on a perfectly healthy clone.
# Order: hive.yml (authoritative) → the remote's published HEAD (set by `git clone`, and it
# survives --depth 1 --sparse --filter=blob:none) → `master` (the pre-2.x default).
resolve_default_branch() {
  local db
  db=$(grep -E '^default_branch:' hive.yml 2>/dev/null | head -1 \
       | sed -E 's/^default_branch:[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'"'"']//g; s/[[:space:]]+$//' \
       | tr -d '\r')
  [ -n "$db" ] || db=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's#^origin/##')
  echo "${db:-master}"
}

if [ -d "$HIVE_DIR/.git" ]; then
  cd "$HIVE_DIR"
  DEFAULT_BRANCH=$(resolve_default_branch)
  # Normalize to default branch before syncing. HALT if on a feature branch so
  # Orphaned Branch Recovery can preserve unpushed work *before* we switch away.
  CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
    echo "HALT_ORPHANED_BRANCH: clone is on '$CURRENT_BRANCH', not '$DEFAULT_BRANCH'." >&2
    echo "Run Orphaned Branch Recovery, then re-run Step 0." >&2
    exit 1
  fi
elif [ -d "$HIVE_DIR" ]; then
  echo "ERROR: $HIVE_DIR exists but is not a git repo." >&2
  echo "It may hold uncommitted inbox work. Inspect it before deleting:" >&2
  echo "  ls -la $HIVE_DIR" >&2
  echo "If safe to remove: rm -rf $HIVE_DIR && re-run this skill." >&2
  exit 1
else
  git clone --depth 1 --sparse --filter=blob:none \
    {REMOTE} "$HIVE_DIR"
  cd "$HIVE_DIR"
  # `/CLAUDE.md` and `/README.md` are anchored root files audit reads; `_metrics/` is written by
  # every session (Ask step 5) and `.signal/` holds the Signal config audit checks — all four were
  # outside the sparse set, so the session wrote into and audited paths it had never checked out.
  git sparse-checkout set --no-cone PROTOCOL/ knowledge/ sources/ /hive.yml /CLAUDE.md /README.md \
    _inbox/ _custodian/ _metrics/ .signal/ .claude/
  DEFAULT_BRANCH=$(resolve_default_branch)
fi

# --- Sync to the remote default branch (HALT if not fast-forwardable) ---
git fetch origin "$DEFAULT_BRANCH" --depth 1 --quiet
git merge --ff-only "origin/$DEFAULT_BRANCH" 2>/dev/null || {
  echo "ERROR: Hive clone cannot fast-forward to origin/$DEFAULT_BRANCH." >&2
  echo "Likely cause: local commits on $DEFAULT_BRANCH that were never pushed." >&2
  echo "Before resetting, salvage any unpushed inbox work — run Diverged Default-Branch" >&2
  echo "Recovery (mode-operate.md), then: git -C $HIVE_DIR reset --hard origin/$DEFAULT_BRANCH" >&2
  echo "SESSION HALTED — do not use stale data."
  exit 1
}
echo "DEFAULT_BRANCH_RESOLVED:$DEFAULT_BRANCH"

# --- Queue-branch transport: register + fetch the inbox queue ref (self-resolving from hive.yml) ---
# The sed strips trailing inline comments and whitespace as well as quotes: a value like
# "branch   # comment" must parse to "branch", or the equality test below silently fails and
# the transport deactivates with no error.
INBOX_TRANSPORT=$(grep -E '^inbox_transport:' hive.yml | head -1 | sed -E 's/^inbox_transport:[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'"'"']//g; s/[[:space:]]+$//' | tr -d '\r')
if [ "${INBOX_TRANSPORT:-default-branch}" = "branch" ]; then
  INBOX_BRANCH=$(grep -E '^inbox_branch:' hive.yml | head -1 | sed -E 's/^inbox_branch:[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'"'"']//g; s/[[:space:]]+$//' | tr -d '\r')
  INBOX_BRANCH="${INBOX_BRANCH:-inbox}"
  # The Step 0 clone is --depth 1 and therefore single-branch: without this refspec no fetch
  # ever creates origin/{INBOX_BRANCH}, and the push worktree cannot --track it.
  git config --get-all remote.origin.fetch | grep -qF "refs/heads/${INBOX_BRANCH}:" \
    || git config --add remote.origin.fetch "+refs/heads/${INBOX_BRANCH}:refs/remotes/origin/${INBOX_BRANCH}"
  # Tolerant, separate fetch: combining it with the "$DEFAULT_BRANCH" fetch above would fail the
  # WHOLE fetch when the queue does not exist yet (nobody has pushed) — that is not a HALT state.
  # On failure, distinguish "no queue yet" from "offline with a cached ref": conflating them
  # would make Status report an empty queue when the network is simply down.
  git fetch origin "$INBOX_BRANCH" --quiet 2>/dev/null \
    && echo "INBOX_QUEUE_REF_OK:${INBOX_BRANCH}" \
    || { git rev-parse --verify --quiet "origin/${INBOX_BRANCH}" >/dev/null \
         && echo "INBOX_QUEUE_STALE:${INBOX_BRANCH} (fetch failed — queue reads use the last-synced snapshot)" \
         || echo "INBOX_QUEUE_ABSENT:${INBOX_BRANCH}"; }
fi

# --- Install / refresh the pre-push Sentinel hook (enforcement layer) ---
HIVE_ROOT="$HIVE_DIR"
APIARY_ASSETS="{APIARY_ROOT}/skills/apiary/assets"
if [ -f "$APIARY_ASSETS/generate-hook.sh" ]; then
  mkdir -p "$HIVE_ROOT/.githooks"
  HOOK="$HIVE_ROOT/.githooks/pre-push"
  # Never clobber a hook this generator did not write. A Hive that hand-rolled
  # a hardened gate here would otherwise be silently downgraded to the bare
  # pattern scan on every operate invocation — and since regeneration prints
  # success, the downgrade is invisible. Hive-specific hardening belongs in
  # `extensions.gates` (references/authoring-gate-extensions.md), which this
  # generator bakes in and therefore preserves across refreshes.
  # The marker comes from the generator itself rather than a second hardcoded
  # copy: were the two to drift, every real Apiary hook would read as foreign.
  SENTINEL_MARKER="$(bash "$APIARY_ASSETS/generate-hook.sh" --print-marker)"
  if [ -f "$HOOK" ] && ! grep -qF "$SENTINEL_MARKER" "$HOOK" 2>/dev/null; then
    echo "WARN_FOREIGN_PREPUSH_HOOK: $HOOK was not generated by Apiary; left untouched." >&2
    echo "  Migrate its extra checks to extensions.gates so they survive refreshes." >&2
    git -C "$HIVE_ROOT" config core.hooksPath "$HIVE_ROOT/.githooks"
    echo "SENTINEL_HOOK_PRESERVED_FOREIGN"
  else
    bash "$APIARY_ASSETS/generate-hook.sh" "$APIARY_ASSETS/sentinel-patterns.json" "$HIVE_ROOT" \
      > "$HOOK" \
      && chmod +x "$HOOK" \
      && git -C "$HIVE_ROOT" config core.hooksPath "$HIVE_ROOT/.githooks" \
      && echo "SENTINEL_HOOK_OK"
  fi
  # hooksPath is set ABSOLUTE deliberately: git resolves a relative core.hooksPath against the
  # CURRENT worktree, and the inbox queue worktree (branch transport) does not check out
  # .githooks/ — a relative path there means pushes run NO pre-push hook at all. The clone's
  # location is fixed per-user state, so the absolute path is stable.
else
  echo "WARN_SENTINEL_ASSETS_MISSING: could not resolve apiary assets; hook not refreshed this session." >&2
fi

# --- Emit identity + persona so they load without extra Read round-trips ---
PERSONA_PATH=$(grep -E '^persona:' hive.yml | head -1 | sed -E 's/^persona:[[:space:]]*//; s/["'"'"']//g' | tr -d '\r')
PERSONA_PATH="${PERSONA_PATH:-PROTOCOL/agent-definition.md}"
echo "===HIVE_YML==="
cat hive.yml
echo "===PERSONA:${PERSONA_PATH}==="
cat "$PERSONA_PATH" 2>/dev/null || echo "(persona file not found at $PERSONA_PATH)"
echo "===END==="
```

**Bootstrap order:** Only `{HIVE_SLUG}` and `{REMOTE}` are substituted into this script — read them from the child skill stub's `## Identity` block (`Hive slug:`, `Git remote:`). **`{DEFAULT_BRANCH}` is deliberately NOT substituted here**: the script resolves it itself (`resolve_default_branch`), because the branch-normalize check needs the value before the script reaches `cat hive.yml`, and a session that has never read `hive.yml` can only guess. The resolved value is echoed as `DEFAULT_BRANCH_RESOLVED:<branch>` — parse it and use it as `{DEFAULT_BRANCH}` for every later step (Pre-Push Guard, push procedures, recovery). Later blocks keep the `{DEFAULT_BRANCH}` placeholder form because identity is loaded by the time they run.

**Branch normalization:** The clone must be on the default branch before syncing. If a previous session left the repo on a feature branch, the script halts with `HALT_ORPHANED_BRANCH`; run the Orphaned Branch Recovery procedure below to preserve any work, then re-run the Step 0 script. The HALT message names **both** the branch found and the resolved default (`clone is on 'X', not 'Y'`), so recovery has the value it needs even though the halt prevented `hive.yml` from being emitted.

**Why self-resolution, not a placeholder:** a returning session on a Hive whose `hive.yml` says `default_branch: main` has no way to know that before Step 0 runs. Substituting the documented default (`master`) makes the equality test fail against a perfectly healthy clone, and the session HALTs into Orphaned Branch Recovery for a branch that was never orphaned. Resolution order — `hive.yml` (authoritative, present on every invocation after the first), then `refs/remotes/origin/HEAD` (written by `git clone`; verified to survive `--depth 1 --sparse --filter=blob:none`), then `master`.

**Sentinel hook:** Regenerating on every invocation keeps the hook in lockstep with the installed Apiary version. The generator reads patterns from `assets/sentinel-patterns.json` (single source of truth) and compiles them into a self-contained hook (bash + grep + git only) that respects per-file `sentinel_override` frontmatter. See `protocol/sensitive-data-patterns.md` for the pattern list and override semantics. If the script prints `WARN_SENTINEL_ASSETS_MISSING`, the assets path could not be resolved this session — surface that and resolve it before any push, since the hook is the push-time enforcement gate.

**Gate extensions:** the generator is passed `$HIVE_ROOT` so it can bake this Hive's `extensions.gates` into the emitted hook. Mechanics and authoring contract: `references/authoring-gate-extensions.md`.

**`SENTINEL_HOOK_PRESERVED_FOREIGN`:** the Hive's `.githooks/pre-push` was not generated by Apiary, so it was left in place. Surface it and offer to migrate its checks to `extensions.gates` — see `references/authoring-gate-extensions.md` § Migrating a hand-rolled hook. Do **not** delete or overwrite the foreign hook to silence the warning; read it first, since it usually exists because someone deliberately hardened it.

**This step HALTS on failure** (exit 1) — a non-fast-forwardable state means the clone has diverged from remote and the agent would read stale data. The error message tells the user exactly how to reset.

From the single tool result:
- **`{HIVE_ROOT}`** = `$HOME/.claude-hive/{HIVE_SLUG}` — use for all later steps.
- **`{DEFAULT_BRANCH}`** = the `DEFAULT_BRANCH_RESOLVED:` line. Prefer it over re-deriving from `hive.yml` — it is what the script actually synced against.
- **Identity** — parse the `===HIVE_YML===` section for: `hive_slug`, `description`, `remote`, `default_branch` (cross-check against `DEFAULT_BRANCH_RESOLVED`), `persona`, `codeowners`, `slack_channel`, `purpose` → `{HIVE_PURPOSE}` (scope of what belongs here; may be absent on Hives created before v2.5), `confluence_registry` → `{REGISTRY_URL}`, `siblings` → `{SIBLINGS}` (cached roster of peer Hives, each `{slug, purpose, repo, classification}`), `extensions`, `auto_merge`, `inbox_transport` → `{INBOX_TRANSPORT}` (default `default-branch`), `inbox_branch` → `{INBOX_BRANCH}` (default `inbox`; only read when the transport is `branch`), **and the three groups this list previously omitted even though later steps dispatch on them**:
  - **Push modes** — `push_mode` (default `direct`), `inbox_push_mode`, `parliament_push_mode`, `sources_push_mode`. § Push Procedure below resolves `inbox_push_mode` → `push_mode` → `direct`, and `sources-policy.md` § Push Discipline does the same for deposits. Not parsing them meant the Push Procedure dispatched on values the session had never read.
  - **Classification** — the `classification` block: `classification.max_level` (`UNCLASSIFIED` | `FOUO` | `CUI`; an absent block means `UNCLASSIFIED` with no marking discipline) and `classification.marking_required`. The always-on invariant "never store content above the Hive's classification ceiling" cannot be held without the ceiling, and `marking_required` decides whether inbox and source frontmatter must carry a `classification` field at all (`sources-policy.md` § Frontmatter Schema).
  - **Federation** — the `federation` block: `cross_hive_routing` and `register` (both default `true`). § Contribution Handling's cross-hive advisory and `workflows.md` § Contribute skip entirely when `cross_hive_routing` is `false`; absent the field, the advisory fires on a Hive that opted out.
- **Persona** — the `===PERSONA:…===` section is the agent-definition. Adopt its name, voice, and routing rules. **If it contains a `## Greeting Banner` section, that is the greeting — see Step 1.**

### Orphaned Branch Recovery

If the Step 0 script halts with `HALT_ORPHANED_BRANCH` (the clone is on a non-default branch), preserve any work before switching:

1. **Check for uncommitted changes** (`git -C "$HIVE_DIR" status --porcelain`). If there are any:
   - Stage all changes: `git add -A`
   - Commit with message: `recovered: uncommitted work from orphaned branch {BRANCH_NAME}`
2. **Check for unpushed commits** (`git log origin/{CURRENT_BRANCH}..HEAD` or `git log --oneline HEAD ^origin/{DEFAULT_BRANCH}`). If there are local commits not on remote:
   - Push the branch to remote: `git push origin {CURRENT_BRANCH}` (creates the remote branch if needed)
   - Open a draft PR: `gh pr create --draft --title "recovered: orphaned branch {CURRENT_BRANCH}" --body "This branch was found in a local Hive clone during session startup. A previous agent session may have left uncommitted work. Codeowners: please review and merge or close."`
   - Add codeowner reviewers: `gh pr edit {PR_URL} --add-reviewer {CODEOWNERS_CSV}`
   - Log: `"Orphaned branch '{CURRENT_BRANCH}' preserved as draft PR #{NUMBER}. Switching to {DEFAULT_BRANCH}."`
3. **If the branch has no uncommitted changes and no unpushed commits** — it's a clean leftover. Just switch branches; nothing to preserve.

After recovery, `git -C "$HIVE_DIR" checkout {DEFAULT_BRANCH}` and re-run the Step 0 script.

### Diverged Default-Branch Recovery

If Step 0's ff-sync HALTs (local commits on `{DEFAULT_BRANCH}` that never pushed — most commonly a
clone that committed inbox entries while offline, or a straggler session that committed before a
transport cutover protected the branch), do **not** reset until unpushed work is preserved:

1. List what the local branch is ahead by: `git log --oneline origin/{DEFAULT_BRANCH}..HEAD`.
2. Salvage any inbox entries in those commits:
   `git diff --name-only origin/{DEFAULT_BRANCH}..HEAD -- _inbox/` — copy each listed file
   (via `git show HEAD:<path>`) to a temp directory.
3. Reset: `git reset --hard origin/{DEFAULT_BRANCH}`.
4. Re-inject the salvaged entries through the **currently active transport** — the Queue-branch
   push block when `inbox_transport: branch`, the normal inbox push otherwise. Their filenames are
   already unique, so re-pushing is conflict-free.
5. Non-inbox local commits (rare — sessions should never produce them) follow the Orphaned Branch
   Recovery pattern instead: push them to a rescue branch and open a draft PR.

No work is silently lost: the failure the raw `reset --hard` instruction alone would cause is a
straggler's committed-but-unpushed contributions vanishing with the reset.

## Step 1: Greeting

Keep the greeting short — it is the last turn before the user can act, so a long freeform banner directly adds latency.

- **If the persona (from Step 0) has a `## Greeting Banner` section:** output it **verbatim** and stop. Do not embellish or expand it.
- **Otherwise:** emit at most three lines and then wait for input — (1) the persona name + one-line role, (2) one line naming the top-level topic areas it covers, (3) one line listing the control words (`status`, `parliament`, `audit`, "I learned…"). Do **not** compose a capability table, per-topic descriptions, or example questions; the routing table already holds that detail and the user will ask.

## Step 2: Load Upstream Protocol — routing summary only (lazy)

Keep this compact routing table in mind and read the matching file(s) from the Apiary skill's `protocol/` directory **only when that workflow actually runs**:

| Read this protocol file… | …only when |
|---|---|
| `workflows.md` | executing any workflow whose steps aren't already in context |
| `triage-policy.md` | routing a **Contribute** (deciding fast-path vs. deliberation) |
| `security-policy.md` | writing to `_inbox/` or any **Contribute** / Sentinel path (CUI/PII/injection checks) |
| `sensitive-data-patterns.md` | interpreting a pre-push Sentinel block, or reasoning about what the hook flags |
| `knowledge-schema.md` | writing an inbox entry (frontmatter shape) |
| `routing-protocol.md` | answering an **Ask** — always. The RLDP runs on every Ask (stated in `routing-protocol.md`'s header); a routing-table hit does not establish sufficiency, which is exactly the case §Search's augment path exists for |
| `custodian-workflow.md` | running **Parliament** (includes Sentinel, registry reconciliation §1.4, and cross-hive routing §2.1) |
| `operational-model.md` | you need the session→accumulation→incorporation model |
| `learning-loops.md` | deciding whether a discovery/correction must be captured (see Learning Loop Enforcement) |
| `design-goals.md` | running **Audit** or a self-check |
| `document-quality.md` | reading or authoring `type: index` catalog rows (field semantics beyond the authority ranking §Prefer inlines) |
| `tool-tiers.md` | resolving which tool reaches a store, or degrading on a missing tool |
| `sources-policy.md` | running a **Deposit** |
| `external-search-agent.md` | dispatching RLDP §Search |

Apiary is a hard dependency. If its `protocol/` directory is unavailable, fail loudly:
> ERROR: Apiary plugin required but not installed. Run: `claude plugin install apiary@ahartzog`

**Always-on invariants** (do not need a file read — hold these every session): never store content above the Hive's classification ceiling; every user correction and every reusable artifact produced becomes an inbox contribution before the session ends; cite knowledge sources.

## Step 3: Merge Extensions

Extensions are **additive only** — they add rows and fields, never remove or override upstream
behavior (Apiary plugin-root `DESIGN-GOALS.md` principle 3).

If `extensions.workflows` is not null:
- Read every `*.md` file at the declared path (a directory loads all of them; a file loads one)
- Load only files whose frontmatter carries `type: workflow-extension`. Skip anything else and
  warn once: `WARNING: {path} in extensions.workflows is not a workflow-extension — ignored.`
- For each loaded file, take the row(s) under its `## Dispatch Table Addition` heading and
  **append** them to the Step 4 dispatch table, keeping the `(this extension)` marker so the
  merged table stays legible
- Read the extension's disambiguation prose. When the user's input could match both an upstream
  workflow and an extension, that prose decides. If it is missing or does not resolve the
  ambiguity, **ask the user which they meant** — do not guess, and do not let the extension
  silently shadow an upstream workflow
- If an extension's `workflow` name collides with an upstream workflow name, the upstream
  workflow wins. Report it: `WARNING: extension workflow '{name}' collides with an upstream
  workflow — upstream retained. Rename the extension.`
- Do not eagerly load files the extension delegates to (its `knowledge/` mechanics docs). Load
  those only when that workflow is actually dispatched

Format spec, frontmatter contract, and authoring guidance for these files:
[`references/authoring-workflow-extensions.md`](authoring-workflow-extensions.md)
(schema: `assets/workflow-extension.schema.json`, scaffold:
`assets/workflow-extension-template.md`).

If `extensions.knowledge_schema` is not null:
- Read schema definition from the declared path
- Append custom fields to the upstream-required frontmatter set

If `extensions.triage_routing` is not null:
- Read routing rules from the declared path
- Append to the upstream triage routing table

## Step 4: Detect and Execute Workflow

Use the workflow dispatch table (upstream + any extensions) to route the user's input:

| Input Pattern | Workflow |
|---|---|
| Any question, no explicit keyword, onboarding ("I'm new," "onboard me," "where do I start"), or ambiguous input | **Ask** (default) |
| "What's the status," "what's blocked," "current state" | **Status** |
| "I learned X," "here's a link," "this fact is wrong" | **Contribute** |
| `parliament` | **Parliament** |
| `audit` | **Audit** (delegates to mode-audit.md) |
| "Weekly summary," "digest," "what did we learn" | **Brief** |
| "Deposit this transcript," "store this source," "add to sources" | **Deposit** |

Execute the matched workflow per `protocol/workflows.md` — read it now if you haven't already this session.

## Parliament Execution

When Parliament workflow is triggered, follow the Parliament Operational Runbook in `protocol/custodian-workflow.md`.

## Contribution Handling

**Any reusable artifact produced during a session is a contribution** — not just corrections and facts. Guides, directories, decisions with lasting relevance all qualify. Ephemeral debugging output does not.

**Artifact contribution is a task-completion gate.** Before marking any task complete, evaluate internally: *did this session produce something a future user of this Hive would benefit from knowing?* If yes, write the inbox entry and push — do not ask the user for confirmation. Inbox writes are low-cost and Parliament reviews everything before it reaches knowledge files.

**Cross-hive advisory (non-blocking).** Requires `federation.cross_hive_routing` (default `true`); if it is `false`, skip this advisory entirely. `{SIBLINGS}` is whatever `hive.yml` already holds — never fetch it at session time, and if it is empty this advisory simply does not fire. If a contribution clearly falls outside this Hive's `{HIVE_PURPOSE}` and matches a sibling's purpose in `{SIBLINGS}` better, you may say so and point the user to the better-matching `/sibling-slug` — *after* still capturing it here (Parliament does the authoritative routing). Never withhold or redirect a contribution on this basis at session time; this is a gentle pointer, not a gate. **Classification direction:** before naming a sibling, apply the direction guard — `custodian-workflow.md` §2.1 step 5 (authoritative); never point controlled content toward a lower-ceiling sibling.

### Pre-Push Guard

Applies to pushes targeting `{DEFAULT_BRANCH}` (the `default-branch` transport, and any
Parliament/sources flow pushing there). Queue-branch pushes carry their own identical
fetch → rebase → retry guard inside the Queue-branch push block below — same discipline, different
ref. Before every `git push`, rebase onto the remote default branch to keep history linear:

```bash
cd "{HIVE_ROOT}"
git fetch origin {DEFAULT_BRANCH} --quiet
git rebase origin/{DEFAULT_BRANCH} --quiet 2>/dev/null || {
  git rebase --abort 2>/dev/null
  echo "HALT_REBASE_CONFLICT: rebase onto origin/{DEFAULT_BRANCH} failed — do not push." >&2
  echo "A knowledge or protocol file was probably modified locally. Inspect with: git -C {HIVE_ROOT} status" >&2
  exit 1
}
```

On `HALT_REBASE_CONFLICT`, do not attempt the push — the working tree has been restored (rebase aborted); surface the conflict to the user. Inbox-only writes cannot conflict (unique filenames), so a conflict here means something outside `_inbox/` was touched locally.

### Pre-Push Sentinel — Hook-Driven

The pre-push scan runs as a `git pre-push` hook installed in Step 0 (`{HIVE_ROOT}/.githooks/pre-push`). The hook reads patterns from `sentinel-patterns.json` and exits non-zero on any uncovered match. **The hook is the gate** — protocol prose alone cannot enforce this; the hook can.

When `git push` exits non-zero with the hook's "Pre-push Sentinel block" message on stderr, **follow the diagnose-and-classify runbook in [`references/pre-push-sentinel.md`](pre-push-sentinel.md)**. In brief: read each flagged match in context, then redact in place (Case A — the common case), record a user-approved override only for a genuine false positive (Case B), or stop and hand back to the user when the content is irreducible (Case C). Do not retry blindly, do not bypass with `--no-verify`, and do not edit the patterns file to silence a match.

### Push Procedure

**Resolve the transport first** (it precedes push-mode resolution): `{INBOX_TRANSPORT}` = `hive.yml.inbox_transport`; an **absent field means `default-branch`** (the pre-2.23.0 compatibility semantics — an existing Hive never changes transports without an explicit `hive.yml` edit). New Hives are scaffolded with `inbox_transport: branch`, the recommended transport.

- **`branch`** → inbox entries push **direct to the queue branch** `{INBOX_BRANCH}` (default `inbox`) via the Queue-Branch Push block below. `inbox_push_mode` and `push_mode` are **ignored for inbox writes** under this transport — the queue is never PR-gated, so there is no protection to navigate. (Parliament's `parliament_push_mode` is unaffected and should be `pr` when `{DEFAULT_BRANCH}` is protected.) Design and rationale: `references/inbox-transport-design.md`.
- **`default-branch`** (default) → resolve the inbox push mode as before: `hive.yml.inbox_push_mode` if set, else `hive.yml.push_mode`, else `direct`. (The per-flow override lets a Hive push inbox entries direct while Parliament still publishes via `pr` — see `assets/hive.schema.json`.)

**Default to `direct` for inbox** (default-branch transport). The inbox is a low-cost capture buffer, not a publishing surface — Parliament reviews every entry downstream before it reaches `knowledge/`. Routing inbox writes through their own PR adds a gate at the wrong stage: it buys no extra review the inbox needs, and it depends on the PR actually getting merged. `pr` mode is only correct when the default branch is **protected** against direct pushes — on an unprotected branch there is no required gate for GitHub auto-merge to wait on, so `gh pr merge --auto` is rejected and the PR is left open (see the `pr` block below). Only use `pr` for the inbox when direct push is actually rejected. A Hive that protects its default branch outright should prefer `inbox_transport: branch` over `inbox_push_mode: pr` — same capture friction, none of the policy-bot setup.

#### Queue-branch push (transport resolves to `branch`)

The session's working clone stays on `{DEFAULT_BRANCH}` throughout — inbox commits are made in a
persistent linked worktree at `{HIVE_ROOT}/.inbox-worktree`, checked out to a local
`{INBOX_BRANCH}` branch tracking `origin/{INBOX_BRANCH}`. Three steps, in order: **(A)** ensure
the worktree exists (bash block below), **(B)** write the session's entry file into the
**worktree's** `_inbox/` — not the main clone's — then **(C)** commit and push (second bash
block). The write happens between the blocks because the worktree may not exist until block A has
run.

**Block A — ensure the queue branch and worktree exist** (idempotent; one bash call):

```bash
cd "{HIVE_ROOT}"
WT="{HIVE_ROOT}/.inbox-worktree"

# A1. Bootstrap the queue branch if the remote does not have it yet (orphan root — shares no
#     history with {DEFAULT_BRANCH}).
if ! git ls-remote --exit-code --heads origin "{INBOX_BRANCH}" >/dev/null 2>&1; then
  ROOT_COMMIT=$(git commit-tree "$(git hash-object -t tree /dev/null)" -m "inbox: queue root (transport=branch)")
  if ! git push origin "${ROOT_COMMIT}:refs/heads/{INBOX_BRANCH}" 2>/dev/null; then
    # Two distinct causes — disambiguate, never swallow:
    if git ls-remote --exit-code --heads origin "{INBOX_BRANCH}" >/dev/null 2>&1; then
      : # benign bootstrap race — another session's root won; proceed against theirs
    elif [ -n "$(git ls-remote --heads origin "{INBOX_BRANCH}/*")" ]; then
      echo "HALT_QUEUE_REFNAME_CONFLICT: remote has legacy '{INBOX_BRANCH}/*' branches (old pr-mode" >&2
      echo "  inbox PRs), so the ref '{INBOX_BRANCH}' cannot be created. Merge/close those PRs and" >&2
      echo "  delete their branches, or set a non-colliding hive.yml inbox_branch (e.g. inbox-queue)." >&2
      exit 1
    else
      echo "HALT_QUEUE_BOOTSTRAP_FAILED: could not create '{INBOX_BRANCH}' on the remote." >&2
      exit 1
    fi
  fi
fi
git fetch origin "{INBOX_BRANCH}" --quiet   # refspec was registered by Step 0

# A2. Create or reattach the worktree.
if [ ! -e "$WT/.git" ]; then
  git worktree prune
  if git show-ref --verify --quiet "refs/heads/{INBOX_BRANCH}"; then
    git worktree add "$WT" "{INBOX_BRANCH}"    # reattach — unpushed local commits are preserved
  else
    git worktree add --track -b "{INBOX_BRANCH}" "$WT" "origin/{INBOX_BRANCH}"
  fi
fi
# The main clone's no-cone sparse patterns are repo-shared; the queue checkout must not
# inherit them (the queue tree is only pending _inbox/ files — tiny either way).
git -C "$WT" sparse-checkout disable 2>/dev/null || true
mkdir -p "$WT/_inbox"    # absent on a fresh worktree of the empty orphan root
echo "QUEUE_WORKTREE_READY: $WT"
```

**Block B — write the entry.** Create
`$WT/_inbox/$(date +%Y-%m-%d)-{GIT_USER}-session-{SESSION_ID}.md` with the session's contribution
content (normal file write — the same entry format as the default transport).

**Block C — commit and push** (one bash call; its exit status is the truth about whether the
contribution was recorded):

```bash
cd "{HIVE_ROOT}/.inbox-worktree"

# C1. Commit this session's entry, plus any stray uncommitted top-level _inbox/*.md a crashed
#     session left (the pre-push hook re-gates everything in the push, so nothing abandoned at
#     a Sentinel block can slip through). Stage ONLY the conforming shape — top-level .md files —
#     so the staged surface equals the surface Sentinel scans and Parliament drains.
git add _inbox/*.md
git commit -m "inbox: session {SESSION_ID} contribution"

# C2. Rebase-retry push — the same guard as the default transport, against the queue ref.
#     Unique filenames make the rebase structurally conflict-free.
PUSHED=0
for attempt in 1 2; do
  git fetch origin "{INBOX_BRANCH}" --quiet
  if git merge-base "origin/{INBOX_BRANCH}" HEAD >/dev/null 2>&1; then
    git rebase "origin/{INBOX_BRANCH}" --quiet 2>/dev/null || {
      git rebase --abort 2>/dev/null
      echo "HALT_QUEUE_REBASE_CONFLICT: rebase onto origin/{INBOX_BRANCH} failed — do not push." >&2
      exit 1
    }
  else
    # RE-ROOT GUARD (security-critical — inbox-transport-design.md § Incident response).
    # No merge base = the queue was re-rooted (incident purge). A plain rebase would replay
    # the ENTIRE old queue history — including the purged content — back onto the new root,
    # silently undoing the purge. Replay only commits this machine has not pushed, and only
    # if that range is verifiably THIS machine's own work:
    #   - Boundary: refs/hive/inbox-last-push, recorded ONLY after a successful push (C3).
    #     The remote-tracking ref is NOT a usable boundary — Step 0 or this loop's own fetch
    #     may already have moved it to the new root.
    #   - Own-work check: if any commit in BASE..HEAD has a different author, or touches
    #     anything but top-level _inbox/*.md, it may be a foreign commit folded in by an
    #     earlier rebase during a failed-push window — HALT instead of replaying it; replay
    #     could resurrect the very content the re-root purged.
    BASE=$(git rev-parse -q --verify refs/hive/inbox-last-push || true)
    # Identity anchor: the boundary commit's author IS this machine's author as of its last
    # successful push (a successful push always tops out with this machine's own commit) —
    # no dependency on current git config being set.
    ME=$([ -n "$BASE" ] && git log -1 --format='%ae' "$BASE" 2>/dev/null || true)
    if [ -n "$BASE" ] && [ -n "$ME" ] && git merge-base --is-ancestor "$BASE" HEAD 2>/dev/null \
       && [ -z "$(git log "$BASE"..HEAD --format='%ae' | grep -vxF "$ME")" ] \
       && [ -z "$(git log "$BASE"..HEAD --name-only --format= | grep -vE '^_inbox/[^/]+\.md$|^$')" ]; then
      git rebase --onto "origin/{INBOX_BRANCH}" "$BASE" --quiet 2>/dev/null || {
        git rebase --abort 2>/dev/null
        echo "HALT_QUEUE_REROOT_CONFLICT: could not replay this session's entries onto the re-rooted queue." >&2
        exit 1
      }
    else
      echo "HALT_QUEUE_REROOTED_UNSAFE_RANGE: the queue was re-rooted and the local unpushed" >&2
      echo "  range is missing, stale, or not verifiably this machine's own work. Do NOT rebase." >&2
      echo "  Recover by: (1) copy THIS session's own entry (and any prior entries by this" >&2
      echo "  machine's author that are absent from origin/{INBOX_BRANCH}) out of the worktree;" >&2
      echo "  (2) git worktree remove --force + prune + re-create it from origin/{INBOX_BRANCH}" >&2
      echo "  (the worktree-recovery steps below); (3) restore the copied entries, commit, push." >&2
      exit 1
    fi
  fi
  if git push origin "{INBOX_BRANCH}"; then
    PUSHED=1
    # C3. Record the pushed tip — the re-root guard's boundary. ONLY on success: advancing it
    #     past an unpushed tip would make the guard silently drop this machine's own entries
    #     after a re-root.
    git update-ref refs/hive/inbox-last-push HEAD
    break
  fi
done
[ "$PUSHED" = "1" ] || {
  echo "QUEUE_PUSH_FAILED: contribution committed locally but NOT recorded on the remote." >&2
  exit 1
}
```

If the worktree directory exists but is not functional (`$WT/.git` missing, or git commands in it
fail): salvage any `_inbox/*.md` files inside it to a temp dir, `git worktree remove --force
"$WT"; git worktree prune`, re-run block A, restore the salvaged files into the fresh worktree,
and run block C — no work is silently lost. If block C exits `QUEUE_PUSH_FAILED` (network, auth),
warn the user exactly as the default transport does: the contribution was not recorded on the
remote; the committed entry departs with the next session's push (and if a re-root intervenes
before then, the guard HALTs into the recovery above rather than guessing).

The pre-push Sentinel hook fires on queue pushes exactly as on default-branch pushes (Step 0
installs it with an absolute `core.hooksPath` so worktree pushes resolve it), and its diff base is
`origin/{INBOX_BRANCH}` via the worktree branch's upstream — the scan covers exactly this push's
files. On a Sentinel block, follow `references/pre-push-sentinel.md` as usual. **Gate-extension
caveat:** gates run with the worktree as cwd, where `PROTOCOL/` and `knowledge/` are not checked
out — a gate must resolve its executable via PATH or an absolute path
(`references/authoring-gate-extensions.md`).

#### Direct push (inbox mode resolves to `direct`)

Use when the resolved inbox push mode is `direct` — the default, and the correct choice whenever `{DEFAULT_BRANCH}` is unprotected (or only protected by checks the session can satisfy).

```bash
cd "{HIVE_ROOT}"
INBOX_FILE="_inbox/$(date +%Y-%m-%d)-${GIT_USER}-session-${SESSION_ID}.md"
git add "$INBOX_FILE"
git commit -m "inbox: session ${SESSION_ID} contribution"
git push origin {DEFAULT_BRANCH}
```

**If the push is rejected by branch protection** (remote says "protected branch", "Changes must
be made through a pull request", or GH006), the failure is **not transient** — retrying will never
succeed. Either the Hive moved to `inbox_transport: branch` and this session is running an older
Apiary that cannot see the field (update the plugin), or the branch was protected without
configuring an inbox path (`inbox_push_mode: pr` + `references/push-mode-pr-setup.md`, or the
queue transport). Surface the specific cause to the user rather than the generic
"couldn't push" warning; audit Step 4b diagnoses the configuration.

#### PR + auto-merge (inbox mode resolves to `pr`)

Use when `{DEFAULT_BRANCH}` is protected and direct push is rejected. The session opens a short-lived PR and calls `gh pr merge --auto --squash`; the PR self-merges once the required checks pass and policy-bot approves. **This mode requires branch protection.** GitHub only arms auto-merge on a PR that is currently blocked by a required check or required review — on an unprotected branch the PR is already mergeable, so `gh pr merge --auto` is rejected ("Pull request is in clean status"), the session moves on, and the PR sits open unmerged. If a branch is unprotected, use `direct` instead (or merge the PR outright rather than requesting `--auto`).

See `references/push-mode-pr-setup.md` for the full runtime procedure (prerequisites, bash block, protected-path caveat) and one-time operator setup.

## Learning Loop Enforcement

Per `protocol/learning-loops.md` (canonical — load it when deciding whether something must be captured), evaluated before any workflow completes. The session-side contract in two lines:

- **In-session (Loops A/B):** every user correction, every reusable artifact, and **every routing gap you hit** becomes an inbox contribution before the session ends. Capture without findability is not a completed loop.
- **Parliament-side (Loops C/D):** a session's only job is emitting the signals they consume — `[meta]` observations for miscalibration, and `[contradiction]` (not `[correction]`) for conflicts you cannot source.
