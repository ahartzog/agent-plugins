#!/usr/bin/env bash
set -euo pipefail

# Hermetic git: the user's global/system config must not leak into fixture
# repos — a globally-installed hook suite (core.hooksPath, e.g. ggshield)
# would otherwise intercept fixture pushes and fail setup unauthenticated.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=apiary-test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=apiary-test GIT_COMMITTER_EMAIL=test@example.invalid
# Exercises the git-flow scenarios from mode-operate.md Step 0.
# Tests against a local bare repo using file:// protocol (required for
# --depth/--filter to work with local repos). Uses a temp HOME so it
# can't clobber real hive state.
#
# Covers the three canonical user scenarios from CONTRIBUTING.md:
#   1. First install — no clone exists
#   2. Returning user — clone exists, remote is ahead
#   3. Rogue branch — previous session left clone on wrong branch
# Plus edge cases:
#   4. Corrupted dir (exists but no .git)
#   5. Parent .claude-hive/ exists, leaf doesn't (second hive install)
#   6. Rogue branch with uncommitted changes
# Plus the queue-branch transport scenarios (inbox_transport: branch —
# references/inbox-transport-design.md, CONTRIBUTING.md Scenario 4):
#   B0. Step 0 transport parse — the grep/sed pipeline survives the template's
#       inline comments and trailing whitespace
#   B1. First queue push — refspec registration, orphan bootstrap, worktree
#       creation from a sparse+filtered clone, Sentinel hook fires from the
#       worktree (absolute hooksPath), master untouched
#   B2. Returning session — second push through the existing worktree
#   B3. Two concurrent queue pushes racing — rebase-retry, both entries land
#   B4. Parliament consume+delete cycle — attribution recorded before the
#       pathspec-limited queue drain, which survives a mid-run session push
#   B5. Re-root guard — purged content must not resurrect from an old-tip
#       worktree; new entries still land
#   B5b. Re-root guard, failed-push window — a foreign commit folded in by a
#       retry rebase must HALT the replay, never resurrect; boundary does not
#       advance on failed pushes
#
# Usage: bash clone-flow.test.sh

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

FAKE_HOME="$TEST_ROOT/home"
FAKE_REMOTE_WORK="$TEST_ROOT/remote-work"
FAKE_REMOTE_BARE="$TEST_ROOT/remote.git"
HIVE_SLUG="testhive"
DEFAULT_BRANCH="master"

mkdir -p "$FAKE_HOME" "$FAKE_REMOTE_WORK"

# Build a realistic fake upstream
(
  cd "$FAKE_REMOTE_WORK" || exit 1
  git init -q -b master
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p PROTOCOL knowledge _inbox
  echo "# protocol" > PROTOCOL/agent-definition.md
  echo "# knowledge" > knowledge/seed.md
  printf "hive_slug: %s\ndefault_branch: master\n" "$HIVE_SLUG" > hive.yml
  git add -A
  git commit -q -m "seed"
)
git clone -q --bare "$FAKE_REMOTE_WORK" "$FAKE_REMOTE_BARE"

# Use file:// so --depth and --filter work with local repos
REMOTE_URL="file://$FAKE_REMOTE_BARE"

# The Step 0 snippet from mode-operate.md, adapted for local testing.
run_step0() {
  HOME="$FAKE_HOME" bash -c '
    set -uo pipefail
    HIVE_DIR="${HOME}/.claude-hive/'"$HIVE_SLUG"'"
    DEFAULT_BRANCH="'"$DEFAULT_BRANCH"'"
    REMOTE_URL="'"$REMOTE_URL"'"
    mkdir -p "$(dirname "$HIVE_DIR")"
    if [ -d "$HIVE_DIR/.git" ]; then
      cd "$HIVE_DIR"
      CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
      if [ "$CURRENT_BRANCH" != "$DEFAULT_BRANCH" ]; then
        echo "BRANCH_DETECTED: $CURRENT_BRANCH"
        git stash --quiet 2>/dev/null || true
        git checkout "$DEFAULT_BRANCH" --quiet 2>/dev/null || {
          echo "ERROR: Cannot switch to $DEFAULT_BRANCH" >&2
          exit 1
        }
        echo "SWITCHED_TO: $DEFAULT_BRANCH"
      fi
      git fetch origin "$DEFAULT_BRANCH" --quiet 2>/dev/null || true
      git merge --ff-only "origin/$DEFAULT_BRANCH" 2>/dev/null || {
        echo "ERROR: Cannot fast-forward to origin/$DEFAULT_BRANCH" >&2
        exit 1
      }
    elif [ -d "$HIVE_DIR" ]; then
      echo "ERROR: $HIVE_DIR exists but is not a git repo." >&2
      exit 1
    else
      git clone --depth 1 --filter=blob:none \
        "$REMOTE_URL" "$HIVE_DIR" 2>&1
      cd "$HIVE_DIR"
    fi
  '
}

PASS=0
FAIL=0

check() {
  local name="$1" expected_rc="$2" actual_rc="$3" expected_match="$4" actual_output="$5"
  if [ "$expected_rc" = "$actual_rc" ] && [[ "$actual_output" == *"$expected_match"* ]]; then
    echo "PASS: $name"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $name"
    echo "  expected rc=$expected_rc, got rc=$actual_rc"
    echo "  expected output to contain: $expected_match"
    echo "  actual output:"
    printf '    %s\n' "$actual_output" | head -20
    FAIL=$((FAIL + 1))
  fi
}

# --- Scenario 1: First install (fresh clone) ---
echo "=== Scenario 1: First Install ==="
rm -rf "$FAKE_HOME/.claude-hive"
rc=0; output=$(run_step0 2>&1) || rc=$?
check "fresh install clones successfully" 0 "$rc" "" "$output"
if [ -f "$FAKE_HOME/.claude-hive/$HIVE_SLUG/hive.yml" ]; then
  echo "  hive.yml present after clone: OK"
else
  echo "  hive.yml missing after clone: FAIL"; FAIL=$((FAIL + 1))
fi

# --- Scenario 2: Returning user (remote ahead) ---
echo ""
echo "=== Scenario 2: Returning User ==="
# Push a new commit via a fresh full clone (avoids shallow/force issues)
PUSH_CLONE="$TEST_ROOT/push-clone"
git clone -q "$FAKE_REMOTE_BARE" "$PUSH_CLONE"
(
  cd "$PUSH_CLONE" || exit 1
  git config user.email "test@example.com"
  git config user.name "Test"
  echo "new knowledge" > knowledge/update.md
  git add -A
  git commit -q -m "new knowledge added"
  git push -q origin master
)
rm -rf "$PUSH_CLONE"
# Run step0 — should fetch and ff-merge the new commit
rc=0; output=$(run_step0 2>&1) || rc=$?
check "returning user pulls new commits" 0 "$rc" "" "$output"
if [ -f "$FAKE_HOME/.claude-hive/$HIVE_SLUG/knowledge/update.md" ]; then
  echo "  new knowledge file visible: OK"
else
  echo "  new knowledge file missing: FAIL"; FAIL=$((FAIL + 1))
fi

# --- Scenario 3a: Rogue branch (clean, with committed changes) ---
echo ""
echo "=== Scenario 3a: Rogue Branch (clean) ==="
git -C "$FAKE_HOME/.claude-hive/$HIVE_SLUG" checkout -q -b fix-typo
echo "typo fix" >> "$FAKE_HOME/.claude-hive/$HIVE_SLUG/knowledge/seed.md"
git -C "$FAKE_HOME/.claude-hive/$HIVE_SLUG" add -A
git -C "$FAKE_HOME/.claude-hive/$HIVE_SLUG" commit -q -m "fix typo on branch"
rc=0; output=$(run_step0 2>&1) || rc=$?
check "rogue branch detected" 0 "$rc" "BRANCH_DETECTED: fix-typo" "$output"
check "switched back to default branch" 0 "$rc" "SWITCHED_TO: master" "$output"
ACTUAL_BRANCH=$(git -C "$FAKE_HOME/.claude-hive/$HIVE_SLUG" rev-parse --abbrev-ref HEAD)
if [ "$ACTUAL_BRANCH" = "master" ]; then
  echo "  now on master: OK"
else
  echo "  still on $ACTUAL_BRANCH: FAIL"; FAIL=$((FAIL + 1))
fi

# --- Scenario 3b: Rogue branch with uncommitted changes ---
echo ""
echo "=== Scenario 3b: Rogue Branch (dirty working tree) ==="
git -C "$FAKE_HOME/.claude-hive/$HIVE_SLUG" checkout -q -b messy-session
echo "unsaved inbox work" >> "$FAKE_HOME/.claude-hive/$HIVE_SLUG/knowledge/seed.md"
# Leave changes uncommitted — stash should handle this
rc=0; output=$(run_step0 2>&1) || rc=$?
check "dirty rogue branch detected" 0 "$rc" "BRANCH_DETECTED: messy-session" "$output"
check "dirty rogue branch recovered to master" 0 "$rc" "SWITCHED_TO: master" "$output"

# --- Case 4: Corrupted dir (exists but no .git) ---
echo ""
echo "=== Edge Case: Corrupted Directory ==="
rm -rf "$FAKE_HOME/.claude-hive"
mkdir -p "$FAKE_HOME/.claude-hive/$HIVE_SLUG"
echo "prior work" > "$FAKE_HOME/.claude-hive/$HIVE_SLUG/draft-inbox.md"
rc=0; output=$(run_step0 2>&1) || rc=$?
check "corrupted dir refuses with error" 1 "$rc" "exists but is not a git repo" "$output"
if [ -f "$FAKE_HOME/.claude-hive/$HIVE_SLUG/draft-inbox.md" ]; then
  echo "  prior work preserved: OK"
else
  echo "  prior work was deleted: FAIL"; FAIL=$((FAIL + 1))
fi

# --- Case 5: Parent exists, leaf doesn't (second hive) ---
echo ""
echo "=== Edge Case: Second Hive Install ==="
rm -rf "$FAKE_HOME/.claude-hive"
mkdir -p "$FAKE_HOME/.claude-hive/someotherhive/.git"
rc=0; output=$(run_step0 2>&1) || rc=$?
check "second hive install clones successfully" 0 "$rc" "" "$output"

# ============================================================================
# Queue-branch transport scenarios (inbox_transport: branch)
# Fresh fixtures — the shared remote above has been mutated by earlier cases.
# The clone mirrors Step 0's real flags (--depth 1 --sparse --filter=blob:none)
# so worktree/sparse/refspec interactions are exercised as shipped.
# ============================================================================

QB_HOME="$TEST_ROOT/qb-home"
QB_REMOTE_WORK="$TEST_ROOT/qb-remote-work"
QB_REMOTE="$TEST_ROOT/qb-remote.git"
INBOX_BRANCH="inbox"
mkdir -p "$QB_HOME" "$QB_REMOTE_WORK"
(
  cd "$QB_REMOTE_WORK" || exit 1
  git init -q -b master
  git config user.email "test@example.com"
  git config user.name "Test"
  mkdir -p PROTOCOL knowledge _inbox
  echo "# protocol" > PROTOCOL/agent-definition.md
  echo "# knowledge" > knowledge/seed.md
  printf "hive_slug: qbhive\ndefault_branch: master\ninbox_transport: branch\ninbox_branch: inbox\n" > hive.yml
  git add -A
  git commit -q -m "seed"
)
git clone -q --bare "$QB_REMOTE_WORK" "$QB_REMOTE"
QB_URL="file://$QB_REMOTE"
QB_HIVE="$QB_HOME/.claude-hive/qbhive"

git clone -q --depth 1 --sparse --filter=blob:none "$QB_URL" "$QB_HIVE" 2>/dev/null
git -C "$QB_HIVE" sparse-checkout set --no-cone PROTOCOL/ knowledge/ /hive.yml _inbox/ 2>/dev/null

# Sentinel stand-in hook + ABSOLUTE hooksPath, exactly as Step 0 configures it.
# The load-bearing assertion: a relative hooksPath resolves against the CURRENT
# worktree, and the queue worktree has no .githooks/ — so with a relative path,
# queue pushes would run NO pre-push hook at all (silent Layer 0 bypass).
mkdir -p "$QB_HIVE/.githooks"
printf '#!/bin/bash\necho "SENTINEL_HOOK_FIRED" >&2\nexit 0\n' > "$QB_HIVE/.githooks/pre-push"
chmod +x "$QB_HIVE/.githooks/pre-push"
git -C "$QB_HIVE" config core.hooksPath "$QB_HIVE/.githooks"

# The queue-push block from mode-operate.md "Queue-branch push", parameterized.
qb_push() {
  local entry_name="$1"
  local entry_body="$2"
  git -C "$QB_HIVE" config --get-all remote.origin.fetch | grep -qF "refs/heads/${INBOX_BRANCH}:" \
    || git -C "$QB_HIVE" config --add remote.origin.fetch "+refs/heads/${INBOX_BRANCH}:refs/remotes/origin/${INBOX_BRANCH}"
  if ! git -C "$QB_HIVE" ls-remote --exit-code --heads origin "$INBOX_BRANCH" >/dev/null 2>&1; then
    local root
    root=$(git -C "$QB_HIVE" commit-tree "$(git -C "$QB_HIVE" hash-object -t tree /dev/null)" -m "inbox: queue root (transport=branch)")
    git -C "$QB_HIVE" push -q origin "${root}:refs/heads/${INBOX_BRANCH}" 2>/dev/null || true
  fi
  git -C "$QB_HIVE" fetch origin "$INBOX_BRANCH" --quiet
  local wt="$QB_HIVE/.inbox-worktree"
  if [ ! -e "$wt/.git" ]; then
    git -C "$QB_HIVE" worktree prune
    if git -C "$QB_HIVE" show-ref --verify --quiet "refs/heads/${INBOX_BRANCH}"; then
      git -C "$QB_HIVE" worktree add "$wt" "$INBOX_BRANCH" >/dev/null 2>&1
    else
      git -C "$QB_HIVE" worktree add --track -b "$INBOX_BRANCH" "$wt" "origin/${INBOX_BRANCH}" >/dev/null 2>&1
    fi
    git -C "$wt" sparse-checkout disable 2>/dev/null || true
  fi
  mkdir -p "$wt/_inbox"
  printf '%s\n' "$entry_body" > "$wt/_inbox/$entry_name"
  # Remaining steps run inside the worktree, mirroring the runbook block:
  # stage only the conforming shape; rebase-retry with the re-root guard.
  (
    cd "$wt" || exit 1
    git add _inbox/*.md
    git commit -q -m "inbox: $entry_name"
    for attempt in 1 2; do
      git fetch origin "$INBOX_BRANCH" --quiet
      if git merge-base "origin/${INBOX_BRANCH}" HEAD >/dev/null 2>&1; then
        git rebase "origin/${INBOX_BRANCH}" --quiet 2>/dev/null || { git rebase --abort 2>/dev/null; exit 1; }
      else
        # RE-ROOT GUARD (mirrors mode-operate.md block C verbatim in mechanics): replay only
        # commits this machine has not pushed — bounded by the last-push ref (recorded ONLY on
        # push success), and only if the range is verifiably this machine's own work. B5 pins
        # the resurrection case; B5b pins the foreign-commit-in-range case.
        BASE=$(git rev-parse -q --verify refs/hive/inbox-last-push || true)
        ME=$([ -n "$BASE" ] && git log -1 --format='%ae' "$BASE" 2>/dev/null || true)
        if [ -n "$BASE" ] && [ -n "$ME" ] && git merge-base --is-ancestor "$BASE" HEAD 2>/dev/null \
           && [ -z "$(git log "$BASE"..HEAD --format='%ae' | grep -vxF "$ME")" ] \
           && [ -z "$(git log "$BASE"..HEAD --name-only --format= | grep -vE '^_inbox/[^/]+\.md$|^$')" ]; then
          git rebase --onto "origin/${INBOX_BRANCH}" "$BASE" --quiet 2>/dev/null \
            || { git rebase --abort 2>/dev/null; exit 1; }
        else
          echo "HALT_QUEUE_REROOTED_UNSAFE_RANGE" >&2
          exit 1
        fi
      fi
      if git push origin "$INBOX_BRANCH" 2>&1; then
        git update-ref refs/hive/inbox-last-push HEAD
        exit 0
      fi
    done
    echo "QUEUE_PUSH_FAILED" >&2
    exit 1
  )
}

# --- Scenario B0: Step 0 transport parse vs the template's own comment style ---
echo ""
echo "=== Scenario B0: Queue Transport — Step 0 hive.yml parse ==="
PARSE_FIXTURE="$TEST_ROOT/parse-hive.yml"
# Worst case a real hive.yml can carry: inline comments, trailing spaces, quotes.
printf 'hive_slug: qbhive\ninbox_transport: branch   # opted in 2026-08\ninbox_branch: "inbox"  \n' > "$PARSE_FIXTURE"
PARSED_TRANSPORT=$(grep -E '^inbox_transport:' "$PARSE_FIXTURE" | head -1 | sed -E 's/^inbox_transport:[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'"'"']//g; s/[[:space:]]+$//' | tr -d '\r')
PARSED_BRANCH=$(grep -E '^inbox_branch:' "$PARSE_FIXTURE" | head -1 | sed -E 's/^inbox_branch:[[:space:]]*//; s/[[:space:]]+#.*$//; s/["'"'"']//g; s/[[:space:]]+$//' | tr -d '\r')
if [ "$PARSED_TRANSPORT" = "branch" ]; then
  echo "PASS: transport parses through inline comment"; PASS=$((PASS + 1))
else
  echo "FAIL: transport parsed as '$PARSED_TRANSPORT'"; FAIL=$((FAIL + 1))
fi
if [ "$PARSED_BRANCH" = "inbox" ]; then
  echo "PASS: branch name parses through quotes + trailing spaces"; PASS=$((PASS + 1))
else
  echo "FAIL: branch name parsed as '$PARSED_BRANCH'"; FAIL=$((FAIL + 1))
fi

# --- Scenario B1: first queue push (bootstrap + worktree + hook) ---
echo ""
echo "=== Scenario B1: Queue Transport — First Push ==="
rc=0; output=$(qb_push "2026-08-03-alice-session-1.md" "first entry" 2>&1) || rc=$?
check "first queue push succeeds (bootstrap + worktree)" 0 "$rc" "" "$output"
check "Sentinel hook fired from the queue worktree" 0 "$rc" "SENTINEL_HOOK_FIRED" "$output"
git -C "$QB_HIVE" fetch -q origin "$INBOX_BRANCH"
QUEUE_FILES=$(git -C "$QB_HIVE" ls-tree -r --name-only "origin/$INBOX_BRANCH" -- _inbox/)
if [[ "$QUEUE_FILES" == *"2026-08-03-alice-session-1.md"* ]]; then
  echo "  entry on queue branch: OK"
else
  echo "  entry missing from queue branch: FAIL"; FAIL=$((FAIL + 1))
fi
MAIN_BRANCH_AFTER=$(git -C "$QB_HIVE" rev-parse --abbrev-ref HEAD)
if [ "$MAIN_BRANCH_AFTER" = "master" ]; then
  echo "  main clone still on master: OK"
else
  echo "  main clone left on $MAIN_BRANCH_AFTER: FAIL"; FAIL=$((FAIL + 1))
fi
if git -C "$QB_HIVE" merge-base "origin/$INBOX_BRANCH" origin/master >/dev/null 2>&1; then
  echo "  queue shares history with master: FAIL (must be orphan)"; FAIL=$((FAIL + 1))
else
  echo "  queue history is orphan (no merge base with master): OK"
fi

# --- Scenario B2: returning session pushes through existing worktree ---
echo ""
echo "=== Scenario B2: Queue Transport — Returning Session ==="
rc=0; output=$(qb_push "2026-08-03-alice-session-2.md" "second entry" 2>&1) || rc=$?
check "returning-session queue push succeeds" 0 "$rc" "" "$output"
git -C "$QB_HIVE" fetch -q origin "$INBOX_BRANCH"
N_QUEUED=$(git -C "$QB_HIVE" ls-tree -r --name-only "origin/$INBOX_BRANCH" -- _inbox/ | wc -l | tr -d ' ')
if [ "$N_QUEUED" = "2" ]; then
  echo "  both entries on queue: OK"
else
  echo "  expected 2 queued entries, found $N_QUEUED: FAIL"; FAIL=$((FAIL + 1))
fi

# --- Scenario B3: two concurrent queue pushes racing ---
echo ""
echo "=== Scenario B3: Queue Transport — Concurrent Push Race ==="
# Session B (separate machine): full clone, pushes to the queue FIRST — after
# session A has already committed locally, so A's push is rejected and must
# rebase-retry.
git clone -q "$QB_REMOTE" "$TEST_ROOT/qb-sessionB" 2>/dev/null
(
  cd "$TEST_ROOT/qb-sessionB" || exit 1
  # env identity outranks repo config — override it so B4's attribution check can
  # verify the QUEUE author (not the suite's hermetic identity) is what gets recorded
  export GIT_AUTHOR_NAME=Bob GIT_AUTHOR_EMAIL=bob@example.com
  export GIT_COMMITTER_NAME=Bob GIT_COMMITTER_EMAIL=bob@example.com
  git checkout -q -b "$INBOX_BRANCH" "origin/$INBOX_BRANCH"
  mkdir -p _inbox
  echo "bob entry" > "_inbox/2026-08-03-bob-session-7.md"
  git add _inbox && git commit -q -m "inbox: bob" && git push -q origin "$INBOX_BRANCH"
)
# Session A: commit locally in the worktree, then let qb_push's rebase-retry
# resolve the non-fast-forward.
WT="$QB_HIVE/.inbox-worktree"
echo "alice racing entry" > "$WT/_inbox/2026-08-03-alice-session-3.md"
git -C "$WT" add _inbox/ && git -C "$WT" commit -q -m "inbox: alice race"
rc=0; output=$( { git -C "$WT" fetch origin "$INBOX_BRANCH" --quiet \
  && git -C "$WT" rebase "origin/$INBOX_BRANCH" --quiet \
  && git -C "$WT" push origin "$INBOX_BRANCH"; } 2>&1 ) || rc=$?
check "racing push lands after rebase-retry" 0 "$rc" "" "$output"
git -C "$QB_HIVE" fetch -q origin "$INBOX_BRANCH"
QUEUE_FILES=$(git -C "$QB_HIVE" ls-tree -r --name-only "origin/$INBOX_BRANCH" -- _inbox/)
for f in 2026-08-03-bob-session-7.md 2026-08-03-alice-session-3.md; do
  if [[ "$QUEUE_FILES" == *"$f"* ]]; then
    echo "  $f survived the race: OK"
  else
    echo "  $f lost in the race: FAIL"; FAIL=$((FAIL + 1))
  fi
done

# --- Scenario B4: Parliament consume + delete, attribution preserved ---
echo ""
echo "=== Scenario B4: Queue Transport — Parliament Consume + Delete ==="
PARL="$TEST_ROOT/qb-parliament"
git clone -q --depth 1 "$QB_REMOTE" "$PARL" 2>/dev/null
git -C "$PARL" config user.email "parliament@example.com"
git -C "$PARL" config user.name "Parliament"
# Mirror custodian §0.5: register the queue refspec (single-branch clone), then plain fetch —
# this is what makes §6.3's later plain fetch actually update origin/{INBOX_BRANCH}.
git -C "$PARL" config --get-all remote.origin.fetch | grep -qF "refs/heads/${INBOX_BRANCH}:" \
  || git -C "$PARL" config --add remote.origin.fetch "+refs/heads/${INBOX_BRANCH}:refs/remotes/origin/${INBOX_BRANCH}"
git -C "$PARL" fetch -q origin "$INBOX_BRANCH"
# §1.3 materialize + consumption manifest (attribution BEFORE any deletion)
mkdir -p "$PARL/_inbox"
MANIFEST="$TEST_ROOT/qb-manifest"
: > "$MANIFEST"
PROCESSED=""
for f in $(git -C "$PARL" ls-tree -r --name-only "origin/$INBOX_BRANCH" -- _inbox/); do
  git -C "$PARL" show "origin/${INBOX_BRANCH}:$f" > "$PARL/$f"
  git -C "$PARL" log -1 --format="$f|%H|%an <%ae>|%aI" "origin/$INBOX_BRANCH" -- "$f" >> "$MANIFEST"
  PROCESSED="$PROCESSED $f"
done
BOB_LINE=$(grep "bob-session-7" "$MANIFEST")
BOB_SHA=$(printf '%s' "$BOB_LINE" | cut -d'|' -f2)
BOB_AUTHOR=$(printf '%s' "$BOB_LINE" | cut -d'|' -f3)
if [ -n "$BOB_SHA" ] && [ "$BOB_AUTHOR" = "Bob <bob@example.com>" ]; then
  echo "  attribution captured (sha + author) before deletion: OK"
else
  echo "  attribution capture failed (sha='$BOB_SHA' author='$BOB_AUTHOR'): FAIL"; FAIL=$((FAIL + 1))
fi
# §6.1: MOVE each processed materialized copy into _completed/ with a reconciliation
# note carrying queue_commit/queue_author from the manifest (as the runbook specifies).
mkdir -p "$PARL/_inbox/_completed"
while IFS='|' read -r fpath fsha fauthor fdate; do
  {
    printf -- '---\noriginal: %s\nqueue_commit: %s\nqueue_author: "%s"\n---\n' "$fpath" "$fsha" "$fauthor"
    cat "$PARL/$fpath"
  } > "$PARL/_inbox/_completed/$(basename "$fpath")"
  rm -f "$PARL/$fpath"
done < "$MANIFEST"
if grep -q "queue_commit: $BOB_SHA" "$PARL/_inbox/_completed/2026-08-03-bob-session-7.md"; then
  echo "  completed record carries queue_commit: OK"
else
  echo "  completed record missing queue_commit: FAIL"; FAIL=$((FAIL + 1))
fi
# A session pushes MID-RUN, before the drain — it must survive the deletion.
qb_push "2026-08-03-carol-midrun.md" "carol entry, mid-parliament" >/dev/null 2>&1 \
  || { echo "  mid-run session push failed: FAIL"; FAIL=$((FAIL + 1)); }
# §6.3 pathspec-limited drain with rebase-retry (never forced)
rc=0
output=$(
  cd "$PARL" && {
    # mirror the runbook: clear any leftover materialized copies before the checkout
    for f in $(git ls-tree -r --name-only "origin/$INBOX_BRANCH" -- _inbox/); do rm -f "./$f"; done
    git checkout -q -B "$INBOX_BRANCH" "origin/$INBOX_BRANCH"
    git rm -q -- $PROCESSED
    git commit -q -m "parliament: drain queue — processed (run test)"
    for attempt in 1 2; do
      if git push -q origin "$INBOX_BRANCH" 2>/dev/null; then break; fi
      git fetch -q origin "+refs/heads/${INBOX_BRANCH}:refs/remotes/origin/${INBOX_BRANCH}"
      git rebase -q "origin/$INBOX_BRANCH" 2>/dev/null || { git rebase --abort; exit 1; }
    done
  } 2>&1
) || rc=$?
check "queue drain lands via rebase-retry (no force)" 0 "$rc" "" "$output"
git -C "$QB_HIVE" fetch -q origin "$INBOX_BRANCH"
REMAINING=$(git -C "$QB_HIVE" ls-tree -r --name-only "origin/$INBOX_BRANCH" -- _inbox/)
if [ "$REMAINING" = "_inbox/2026-08-03-carol-midrun.md" ]; then
  echo "  drain removed processed entries, mid-run entry survived: OK"
else
  echo "  unexpected queue state after drain: FAIL"
  printf '    %s\n' "$REMAINING"
  FAIL=$((FAIL + 1))
fi

# --- Scenario B5: incident re-root — old-tip worktree must NOT resurrect purged history ---
echo ""
echo "=== Scenario B5: Queue Transport — Re-Root Guard (purge survives old-tip push) ==="
# Seed a "secret" entry (stand-in for Sentinel-missed content) and let the session worktree
# sync to that tip, so it becomes the old-tip machine.
qb_push "2026-08-03-dave-leak.md" "SECRET_TOKEN=hunter2" >/dev/null 2>&1 \
  || { echo "  seeding leak entry failed: FAIL"; FAIL=$((FAIL + 1)); }
# Operator re-roots: fresh orphan history carrying the survivors minus the leaked file
# (security-policy.md § queue-branch addendum), force-pushed.
REROOT="$TEST_ROOT/qb-reroot"
git clone -q "$QB_REMOTE" "$REROOT" 2>/dev/null
(
  cd "$REROOT" || exit 1
  git fetch -q origin "+refs/heads/${INBOX_BRANCH}:refs/remotes/origin/${INBOX_BRANCH}"
  NEW_ROOT=$(git commit-tree "$(git hash-object -t tree /dev/null)" -m "inbox: queue root (re-rooted)")
  git checkout -q "$NEW_ROOT" 2>/dev/null || git checkout -q --detach "$NEW_ROOT"
  mkdir -p _inbox
  for f in $(git ls-tree -r --name-only "origin/${INBOX_BRANCH}" -- _inbox/); do
    case "$f" in _inbox/2026-08-03-dave-leak.md) continue ;; esac
    git show "origin/${INBOX_BRANCH}:$f" > "$f"
  done
  git add _inbox 2>/dev/null || true
  if ! git diff --cached --quiet 2>/dev/null; then
    git commit -q -m "inbox: survivors (re-root)"
  fi
  git push -q --force origin "HEAD:refs/heads/${INBOX_BRANCH}"
)
# The old-tip session (its worktree still holds pre-re-root history) pushes a new entry.
rc=0; output=$(qb_push "2026-08-03-erin-postreroot.md" "post-re-root entry" 2>&1) || rc=$?
check "old-tip session pushes after re-root" 0 "$rc" "" "$output"
git -C "$QB_HIVE" fetch -q origin "$INBOX_BRANCH"
POST_REROOT=$(git -C "$QB_HIVE" ls-tree -r --name-only "origin/$INBOX_BRANCH" -- _inbox/)
if [[ "$POST_REROOT" == *"dave-leak"* ]]; then
  echo "  PURGED FILE RESURRECTED on the queue tip: FAIL"; FAIL=$((FAIL + 1))
else
  echo "  purged file absent from queue tip: OK"
fi
if git -C "$QB_HIVE" log "origin/$INBOX_BRANCH" --format=%s 2>/dev/null | grep -q "dave-leak"; then
  echo "  purged commit back in queue history: FAIL"; FAIL=$((FAIL + 1))
else
  echo "  purged commit absent from queue history: OK"
fi
if [[ "$POST_REROOT" == *"erin-postreroot"* ]]; then
  echo "  new entry landed on the re-rooted queue: OK"
else
  echo "  new entry missing after re-root: FAIL"; FAIL=$((FAIL + 1))
fi

# --- Scenario B5b: failed-push window — foreign commit in range must HALT, not replay ---
echo ""
echo "=== Scenario B5b: Queue Transport — Re-Root Guard (foreign commit + failed push) ==="
WT="$QB_HIVE/.inbox-worktree"
BOUNDARY_BEFORE=$(git -C "$WT" rev-parse refs/hive/inbox-last-push)
# 1. A foreign machine (Frank) pushes a Sentinel-missed leak.
git clone -q "$QB_REMOTE" "$TEST_ROOT/qb-frank" 2>/dev/null
(
  cd "$TEST_ROOT/qb-frank" || exit 1
  export GIT_AUTHOR_NAME=Frank GIT_AUTHOR_EMAIL=frank@example.com
  export GIT_COMMITTER_NAME=Frank GIT_COMMITTER_EMAIL=frank@example.com
  git checkout -q -b "$INBOX_BRANCH" "origin/$INBOX_BRANCH"
  mkdir -p _inbox
  echo "SECRET_KEY=deadbeef" > "_inbox/2026-08-03-frank-leak.md"
  git add _inbox && git commit -q -m "inbox: frank leak" && git push -q origin "$INBOX_BRANCH"
)
# 2. This machine commits its own entry but its push FAILS (outage: deny hook on the remote).
#    The retry's rebase folds Frank's commit into the local branch below the new entry.
printf '#!/bin/sh\nexit 1\n' > "$QB_REMOTE/hooks/pre-receive"; chmod +x "$QB_REMOTE/hooks/pre-receive"
rc=0; output=$(qb_push "2026-08-03-alice-session-9.md" "own entry, push will fail" 2>&1) || rc=$?
check "push fails during the outage (honest exit status)" 1 "$rc" "QUEUE_PUSH_FAILED" "$output"
BOUNDARY_AFTER=$(git -C "$WT" rev-parse refs/hive/inbox-last-push)
if [ "$BOUNDARY_BEFORE" = "$BOUNDARY_AFTER" ]; then
  echo "  boundary did NOT advance on failed push: OK"
else
  echo "  boundary advanced past an unpushed tip: FAIL"; FAIL=$((FAIL + 1))
fi
rm -f "$QB_REMOTE/hooks/pre-receive"
# 3. Operator re-roots the queue, purging Frank's leak.
REROOT2="$TEST_ROOT/qb-reroot2"
git clone -q "$QB_REMOTE" "$REROOT2" 2>/dev/null
(
  cd "$REROOT2" || exit 1
  NEW_ROOT=$(git commit-tree "$(git hash-object -t tree /dev/null)" -m "inbox: queue root (re-rooted 2)")
  git checkout -q --detach "$NEW_ROOT"
  mkdir -p _inbox
  for f in $(git ls-tree -r --name-only "origin/${INBOX_BRANCH}" -- _inbox/); do
    case "$f" in _inbox/2026-08-03-frank-leak.md) continue ;; esac
    git show "origin/${INBOX_BRANCH}:$f" > "$f"
  done
  git add _inbox 2>/dev/null || true
  git diff --cached --quiet 2>/dev/null || git commit -q -m "inbox: survivors (re-root 2)"
  git push -q --force origin "HEAD:refs/heads/${INBOX_BRANCH}"
)
# 4. This machine pushes again. Its unpushed range now contains Frank's foreign commit —
#    the guard must HALT rather than replay (replay would resurrect the purged leak).
rc=0; output=$(qb_push "2026-08-03-alice-session-10.md" "post-re-root entry" 2>&1) || rc=$?
check "guard HALTs on non-own commits in the replay range" 1 "$rc" "HALT_QUEUE_REROOTED_UNSAFE_RANGE" "$output"
git -C "$QB_HIVE" fetch -q origin "$INBOX_BRANCH"
if git -C "$QB_HIVE" ls-tree -r --name-only "origin/$INBOX_BRANCH" -- _inbox/ | grep -q "frank-leak"; then
  echo "  PURGED LEAK RESURRECTED after failed-push window: FAIL"; FAIL=$((FAIL + 1))
else
  echo "  purged leak absent from queue tip: OK"
fi

echo ""
echo "==============================="
echo "Summary: $PASS passed, $FAIL failed"
exit $FAIL
