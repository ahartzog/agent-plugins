#!/usr/bin/env bash
set -euo pipefail
# Regression tests for sentinel_base() — the commit the pre-push hook diffs
# against when deciding what a push actually changes.
#
# The bug this guards: the no-upstream fallback used to be the EMPTY TREE, so
# the diff became the whole repository. Every contribution starts on a fresh
# branch, so in practice every contribution was reported as changing every
# _inbox/ and sources/ file in the Hive. For the pattern scan that is wasteful;
# for gate extensions it is wrong, because a gate reads its argument list as
# "this contribution" and one asserting a per-contribution property would demand
# it for every pending entry, including other people's.
#
# The failure is invisible in the obvious test: a gate that over-reports still
# blocks bad content, and a repo with one pending entry behaves identically
# either way. It only shows up with pre-existing unrelated inbox entries, which
# is what these fixtures set up.
#
# Usage: bash sentinel-base.test.sh [path-to-generate-hook.sh]

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="${1:-$HERE/../assets/generate-hook.sh}"
PATTERNS="$HERE/../assets/sentinel-patterns.json"

for f in "$GEN" "$PATTERNS"; do
  if [[ ! -f "$f" ]]; then
    echo "sentinel-base.test.sh: required file not found: $f" >&2
    exit 2
  fi
done

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass_count=0
fail_count=0
ZERO=0000000000000000000000000000000000000000

assert_exit() {
  local expected="$1" actual="$2" desc="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS: $desc"; ((pass_count++)) || true
  else
    echo "FAIL: $desc — expected exit $expected, got $actual"; ((fail_count++)) || true
  fi
}

assert_contains() {
  local pattern="$1" file="$2" desc="$3"
  if grep -qE -- "$pattern" "$file"; then
    echo "PASS: $desc"; ((pass_count++)) || true
  else
    echo "FAIL: $desc — output did not contain: $pattern"
    echo "  output: $(cat "$file")"; ((fail_count++)) || true
  fi
}

assert_not_contains() {
  local pattern="$1" file="$2" desc="$3"
  if ! grep -qE -- "$pattern" "$file"; then
    echo "PASS: $desc"; ((pass_count++)) || true
  else
    echo "FAIL: $desc — output unexpectedly contained: $pattern"
    echo "  output: $(cat "$file")"; ((fail_count++)) || true
  fi
}

# --------------------------------------------------------
# Fixture: a Hive with an "origin" to push to, one PRE-EXISTING inbox entry
# already on master, and a gate that simply echoes the files it was handed.
# Echoing the argument list is the whole point — the assertion is about WHICH
# files reach the gate, not whether it blocks.
# --------------------------------------------------------
UPSTREAM="$TEST_ROOT/upstream.git"
HIVE="$TEST_ROOT/hive"
git init -q --bare "$UPSTREAM"

mkdir -p "$HIVE"
cd "$HIVE"
git init -q -b master .
git config user.email test@example.com
git config user.name test
git remote add origin "$UPSTREAM"

mkdir -p PROTOCOL/extensions/gates _inbox scripts

cat > hive.yml <<'EOF'
hive_slug: test-hive
default_branch: master
extensions:
  workflows: null
  gates: PROTOCOL/extensions/gates/
  knowledge_schema: null
  triage_routing: null
EOF

cat > scripts/echo-files.sh <<'EOF'
#!/usr/bin/env bash
# Report exactly what the hook handed us, one per line.
for f in "$@"; do printf 'GATE_SAW %s\n' "$f"; done
exit 0
EOF
chmod +x scripts/echo-files.sh

cat > PROTOCOL/extensions/gates/echo-files.md <<'EOF'
---
layer: PROTOCOL
type: gate-extension
gate: echo-files
command: bash scripts/echo-files.sh
description: >
  Test gate that echoes the candidate file list so the test can assert which
  files the hook considered part of the push.
last_updated: 2026-07-31
codeowners: [test]
on_error: block
timeout_seconds: 30
required_tools: [bash]
---
EOF

# A pending inbox entry that belongs to SOMEONE ELSE's earlier contribution.
cat > _inbox/2026-01-01-other-preexisting.md <<'EOF'
---
author: other
date: 2026-01-01
tag: architecture
status: ready
---
Pre-existing pending entry, unrelated to the contribution under test.
EOF

git add -A
git commit -q -m "base: pre-existing inbox entry on master"
git push -q origin master
BASE_SHA="$(git rev-parse HEAD)"

bash "$GEN" "$PATTERNS" "$HIVE" > "$HIVE/hook.sh"
chmod +x "$HIVE/hook.sh"

# --------------------------------------------------------
# 1. default_branch is baked in from hive.yml
# --------------------------------------------------------
assert_contains '^DEFAULT_BRANCH=master$' "$HIVE/hook.sh" \
  "default_branch baked into the generated hook"

# --------------------------------------------------------
# 2. THE REGRESSION. New branch, no upstream, zero remote sha — the shape of
#    every first contribution push. The gate must see only the new entry.
# --------------------------------------------------------
git checkout -q -b contrib/new-work
cat > _inbox/2026-07-31-me-new-entry.md <<'EOF'
---
author: me
date: 2026-07-31
tag: architecture
status: ready
---
The entry this contribution actually adds.
EOF
git add -A
git commit -q -m "contribution: add one inbox entry"
LOCAL_SHA="$(git rev-parse HEAD)"

rc=0
echo "refs/heads/contrib/new-work $LOCAL_SHA refs/heads/contrib/new-work $ZERO" \
  | bash "$HIVE/hook.sh" origin "$UPSTREAM" > "$TEST_ROOT/out1" 2>&1 || rc=$?

assert_exit 0 "$rc" "new branch with a clean entry passes"
assert_contains 'GATE_SAW _inbox/2026-07-31-me-new-entry\.md' "$TEST_ROOT/out1" \
  "gate sees the entry this contribution adds"
assert_not_contains 'GATE_SAW _inbox/2026-01-01-other-preexisting\.md' "$TEST_ROOT/out1" \
  "gate does NOT see an unrelated pre-existing entry (the regression)"
assert_not_contains 'no upstream and no default branch' "$TEST_ROOT/out1" \
  "no empty-tree warning when the default branch is resolvable"

# --------------------------------------------------------
# 3. Existing remote branch: the remote sha stays authoritative.
# --------------------------------------------------------
git push -q origin contrib/new-work
PUSHED_SHA="$(git rev-parse HEAD)"
cat > _inbox/2026-07-31-me-second-entry.md <<'EOF'
---
author: me
date: 2026-07-31
tag: architecture
status: ready
---
A second entry pushed on top of an already-published branch.
EOF
git add -A
git commit -q -m "contribution: add a second entry"

rc=0
echo "refs/heads/contrib/new-work $(git rev-parse HEAD) refs/heads/contrib/new-work $PUSHED_SHA" \
  | bash "$HIVE/hook.sh" origin "$UPSTREAM" > "$TEST_ROOT/out2" 2>&1 || rc=$?

assert_exit 0 "$rc" "incremental push on a published branch passes"
assert_contains 'GATE_SAW _inbox/2026-07-31-me-second-entry\.md' "$TEST_ROOT/out2" \
  "gate sees the newly added entry"
assert_not_contains 'GATE_SAW _inbox/2026-07-31-me-new-entry\.md' "$TEST_ROOT/out2" \
  "gate does not re-see an entry already on the remote"

# --------------------------------------------------------
# 4. Fail-safe: no resolvable base at all falls back to the full tree AND says
#    so. Over-reporting is the safe direction for the pattern scan, but it must
#    not be silent — a gate behaving oddly on a first push is otherwise very
#    hard to explain.
#
#    Note the fixture has to work for this: a repo whose local branch happens to
#    match `default_branch` resolves through step 2 (merge-base against the local
#    branch), which is correct behavior and not what is under test here. So this
#    orphan sits on a branch named `work`, declares a `default_branch` that does
#    not exist, and has no remote.
# --------------------------------------------------------
ORPHAN="$TEST_ROOT/orphan"
git init -q -b work "$ORPHAN"
cd "$ORPHAN"
git config user.email test@example.com
git config user.name test
mkdir -p PROTOCOL/extensions/gates _inbox scripts
sed 's/^default_branch: .*/default_branch: no-such-branch/' "$HIVE/hive.yml" > hive.yml
cp "$HIVE/scripts/echo-files.sh" scripts/
cp "$HIVE/PROTOCOL/extensions/gates/echo-files.md" PROTOCOL/extensions/gates/
cp "$HIVE/_inbox/2026-01-01-other-preexisting.md" _inbox/
git add -A
git commit -q -m "orphan repo: no remote, default_branch does not exist"

bash "$GEN" "$PATTERNS" "$ORPHAN" > "$ORPHAN/hook.sh"
chmod +x "$ORPHAN/hook.sh"

rc=0
echo "refs/heads/work $(git rev-parse HEAD) refs/heads/work $ZERO" \
  | bash "$ORPHAN/hook.sh" origin "$ORPHAN" > "$TEST_ROOT/out3" 2>&1 || rc=$?

assert_contains 'no upstream and no default branch' "$TEST_ROOT/out3" \
  "unresolvable base warns on stderr instead of failing silently"
assert_contains 'GATE_SAW _inbox/2026-01-01-other-preexisting\.md' "$TEST_ROOT/out3" \
  "unresolvable base falls back to the full tree (fail-safe, over-reports)"

# --------------------------------------------------------
# 5. Back-compat: generated with no HIVE_ROOT, so no baked default_branch.
#    origin/HEAD should still get it there.
# --------------------------------------------------------
cd "$HIVE"
bash "$GEN" "$PATTERNS" > "$HIVE/hook-nohiveroot.sh"
chmod +x "$HIVE/hook-nohiveroot.sh"
assert_contains "^DEFAULT_BRANCH=''$|^DEFAULT_BRANCH=$" "$HIVE/hook-nohiveroot.sh" \
  "no HIVE_ROOT yields an empty baked default_branch"

git remote set-head origin master 2>/dev/null || \
  git symbolic-ref refs/remotes/origin/HEAD refs/remotes/origin/master
git checkout -q -b contrib/nohiveroot master
cat > _inbox/2026-07-31-me-third-entry.md <<'EOF'
---
author: me
date: 2026-07-31
tag: architecture
status: ready
---
Entry pushed from a hook generated without a HIVE_ROOT.
EOF
git add -A
git commit -q -m "contribution: third entry"

rc=0
echo "refs/heads/contrib/nohiveroot $(git rev-parse HEAD) refs/heads/contrib/nohiveroot $ZERO" \
  | bash "$HIVE/hook-nohiveroot.sh" origin "$UPSTREAM" > "$TEST_ROOT/out4" 2>&1 || rc=$?

assert_not_contains 'GATE_SAW _inbox/2026-01-01-other-preexisting\.md' "$TEST_ROOT/out4" \
  "origin/HEAD resolves the base when no default_branch was baked in"

# --------------------------------------------------------
# 6. A credential in sources/**.txt is caught by the pre-push path — pins the
#    list_sentinel_changes filter itself, not just scan-mode content handling.
#    hook.sh lives on the contrib branches' trees (committed by their add -A),
#    so generate a fresh hook OUTSIDE the repo for this case.
# --------------------------------------------------------
git checkout -q master
git checkout -q -b contrib/txt-leak
bash "$GEN" "$PATTERNS" "$HIVE" > "$TEST_ROOT/hook-txt.sh"
chmod +x "$TEST_ROOT/hook-txt.sh"
mkdir -p sources/meeting-transcripts
cat > sources/meeting-transcripts/2026-07-31-me-leaky.txt <<'EOF'
Verbatim transcript. Someone read out loud: password = "hunter2secret"
EOF
git add -A
git commit -q -m "deposit: transcript with a leaked credential"

rc=0
echo "refs/heads/contrib/txt-leak $(git rev-parse HEAD) refs/heads/contrib/txt-leak $ZERO" \
  | bash "$TEST_ROOT/hook-txt.sh" origin "$UPSTREAM" > "$TEST_ROOT/out5" 2>&1 || rc=$?

assert_exit 1 "$rc" "sources/**.txt credential blocks on the pre-push path"
assert_contains 'credential\.password-literal' "$TEST_ROOT/out5" \
  "the .txt match reports its pattern name (list_sentinel_changes filter covers txt)"

# --------------------------------------------------------
echo
echo "----------------------------------------"
echo "  passed: $pass_count"
echo "  failed: $fail_count"
echo "----------------------------------------"
[[ "$fail_count" -eq 0 ]] || exit 1
