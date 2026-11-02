#!/usr/bin/env bash
set -euo pipefail
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=apiary-test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=apiary-test GIT_COMMITTER_EMAIL=test@example.invalid
# Regression tests for scan_history() — the per-commit added-line scan.
#
# The bug this guards: the hook scanned the WORKING-TREE copy of each changed
# file. A secret committed and then removed in a later commit of the same push
# therefore passed, although every commit in the range leaves the machine.
#
# Usage: bash sentinel-history.test.sh [path-to-generate-hook.sh]

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="${1:-$HERE/../assets/generate-hook.sh}"
PATTERNS="$HERE/../assets/sentinel-patterns.json"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT
pass_count=0; fail_count=0
ZERO=0000000000000000000000000000000000000000

assert_exit() {
  if [[ "$2" -eq "$1" ]]; then echo "PASS: $3"; ((pass_count++)) || true
  else echo "FAIL: $3 — expected exit $1, got $2"; ((fail_count++)) || true; fi
}
assert_contains() {
  if grep -qE -- "$1" "$2"; then echo "PASS: $3"; ((pass_count++)) || true
  else echo "FAIL: $3 — output did not contain: $1"; echo "  output: $(cat "$2")"; ((fail_count++)) || true; fi
}
assert_count() {  # pattern file expected desc
  local n; n=$(grep -cE -- "$1" "$2" || true)
  if [[ "$n" -eq "$3" ]]; then echo "PASS: $4"; ((pass_count++)) || true
  else echo "FAIL: $4 — expected $3 match(es) of '$1', got $n"; echo "  output: $(cat "$2")"; ((fail_count++)) || true; fi
}

UPSTREAM="$TEST_ROOT/upstream.git"; HIVE="$TEST_ROOT/hive"
git init -q --bare "$UPSTREAM"
mkdir -p "$HIVE"; cd "$HIVE"
git init -q -b master .
git remote add origin "$UPSTREAM"
mkdir -p _inbox
printf 'hive_slug: test-hive\ndefault_branch: master\n' > hive.yml
git add -A; git commit -q -m base; git push -q origin master
bash "$GEN" "$PATTERNS" "$HIVE" > "$TEST_ROOT/hook.sh"; chmod +x "$TEST_ROOT/hook.sh"
HOOK="$TEST_ROOT/hook.sh"

entry() {  # file body...
  mkdir -p "$(dirname "$1")"
  printf -- '---\nauthor: t\ndate: 2026-07-30\ntag: status\nstatus: ready\n---\n\n%s\n' "$2" > "$1"
}

# 1. Committed, then cleaned, in one push: still blocks, labeled with the sha.
git checkout -q -b contrib/cleaned
entry _inbox/2026-07-30-t-leak.md 'Use key AKIAIOSFODNN7EXAMPLE for access.'
git add -A; git commit -q -m "leak"; LEAK_SHA="$(git rev-parse --short=7 HEAD)"
entry _inbox/2026-07-30-t-leak.md 'Use the key from the vault for access.'
git add -A; git commit -q -m "clean it"
rc=0
echo "refs/heads/contrib/cleaned $(git rev-parse HEAD) refs/heads/contrib/cleaned $ZERO" \
  | "$HOOK" origin "$UPSTREAM" > "$TEST_ROOT/out1" 2>&1 || rc=$?
assert_exit 1 "$rc" "secret committed then cleaned in the same push blocks"
assert_contains "_inbox/2026-07-30-t-leak\.md@$LEAK_SHA" "$TEST_ROOT/out1" \
  "the match names the commit that added the line"
assert_contains 'credential\.aws-access-key' "$TEST_ROOT/out1" "the match names its pattern"

# 2. Committed, then the file deleted: still blocks.
git checkout -q master; git checkout -q -b contrib/deleted
entry _inbox/2026-07-30-t-gone.md 'password = "hunter2secret"'
git add -A; git commit -q -m "leak"
git rm -q _inbox/2026-07-30-t-gone.md; git commit -q -m "delete it"
rc=0
echo "refs/heads/contrib/deleted $(git rev-parse HEAD) refs/heads/contrib/deleted $ZERO" \
  | "$HOOK" origin "$UPSTREAM" > "$TEST_ROOT/out2" 2>&1 || rc=$?
assert_exit 1 "$rc" "secret in a commit whose file was later deleted blocks"

# 3. A secret still present in the working tree is reported once, not twice.
git checkout -q master; git checkout -q -b contrib/present
entry _inbox/2026-07-30-t-here.md 'Contact: SSN 123-45-6789 on file.'
git add -A; git commit -q -m "leak"
rc=0
echo "refs/heads/contrib/present $(git rev-parse HEAD) refs/heads/contrib/present $ZERO" \
  | "$HOOK" origin "$UPSTREAM" > "$TEST_ROOT/out3" 2>&1 || rc=$?
assert_exit 1 "$rc" "secret present in HEAD blocks"
assert_count 'pii\.ssn' "$TEST_ROOT/out3" 1 "working-tree and history hits for the same line dedupe to one"

# 4. An excerpt-bound override in the file's frontmatter covers its own history.
git checkout -q master; git checkout -q -b contrib/overridden
mkdir -p _inbox
cat > _inbox/2026-07-30-t-ov.md <<'OV'
---
author: t
date: 2026-07-30
tag: status
status: ready
sentinel_override:
  patterns: [pii.ssn]
  matches:
    - "Doc example: 123-45-6789 is the IRS sample."
  reason: documented sample number
---

Doc example: 123-45-6789 is the IRS sample.
OV
git add -A; git commit -q -m "overridden sample"
rc=0
echo "refs/heads/contrib/overridden $(git rev-parse HEAD) refs/heads/contrib/overridden $ZERO" \
  | "$HOOK" origin "$UPSTREAM" > "$TEST_ROOT/out4" 2>&1 || rc=$?
assert_exit 0 "$rc" "an override covers the same line in history"

# 5. Clean multi-commit push passes.
git checkout -q master; git checkout -q -b contrib/clean
entry _inbox/2026-07-30-t-a.md 'first'; git add -A; git commit -q -m a
entry _inbox/2026-07-30-t-b.md 'second'; git add -A; git commit -q -m b
rc=0
echo "refs/heads/contrib/clean $(git rev-parse HEAD) refs/heads/contrib/clean $ZERO" \
  | "$HOOK" origin "$UPSTREAM" > "$TEST_ROOT/out5" 2>&1 || rc=$?
assert_exit 0 "$rc" "clean two-commit push passes"

# 6. Remote sha the clone does not have: fall back to a base, do not pass clean.
git checkout -q master; git checkout -q -b contrib/unknown
entry _inbox/2026-07-30-t-u.md 'token xoxb-1234567890-abcdefghij'
git add -A; git commit -q -m leak
FAKE="$(printf 'a%.0s' {1..40})"
rc=0
echo "refs/heads/contrib/unknown $(git rev-parse HEAD) refs/heads/contrib/unknown $FAKE" \
  | "$HOOK" origin "$UPSTREAM" > "$TEST_ROOT/out6" 2>&1 || rc=$?
assert_exit 1 "$rc" "unknown remote sha does not fail open"
assert_contains 'is not in this clone' "$TEST_ROOT/out6" "unknown remote sha is reported"

echo; echo "----------------------------------------"
echo "  passed: $pass_count"; echo "  failed: $fail_count"
echo "----------------------------------------"
[[ "$fail_count" -eq 0 ]] || exit 1
