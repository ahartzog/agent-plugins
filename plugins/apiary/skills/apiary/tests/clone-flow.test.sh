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

echo ""
echo "==============================="
echo "Summary: $PASS passed, $FAIL failed"
exit $FAIL
