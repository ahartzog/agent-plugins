#!/usr/bin/env bash
set -euo pipefail
# Tests for assets/pre-push-sentinel.sh: the range a push scans, and what
# happens when git cannot produce the diff.
#
# Usage: bash pre-push-sentinel.test.sh
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@example.invalid
export GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@example.invalid

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK_SRC="$HERE/../assets/pre-push-sentinel.sh"
PATTERNS_SRC="$HERE/../assets/sentinel-patterns.json"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
ZERO=0000000000000000000000000000000000000000
pass=0; fail=0
ok()   { echo "PASS: $1"; ((pass++)) || true; }
bad()  { echo "FAIL: $1"; ((fail++)) || true; }
expect_exit() { [[ "$2" -eq "$1" ]] && ok "$3" || bad "$3 (expected $1, got $2)"; }

git init -q --bare "$T/remote.git"
git init -q -b main "$T/vault"; cd "$T/vault"
git remote add origin "$T/remote.git"
mkdir -p .claude/hooks; cp "$PATTERNS_SRC" .claude/hooks/sentinel-patterns.json
cp "$HOOK_SRC" .claude/hooks/pre-push-sentinel.sh
echo base > base.md; git add -A; git commit -q -m base; git push -q origin main
run() { printf 'refs/heads/%s %s refs/heads/%s %s\n' "$1" "$2" "$1" "$3" | bash .claude/hooks/pre-push-sentinel.sh origin "$T/remote.git" 2>"$T/err"; }

# 1. New branch, secret in an EARLIER commit than the tip: blocks (used to scan the tip only).
git checkout -q -b feat
echo 'key AKIAIOSFODNN7EXAMPLE' > leak.md; git add -A; git commit -q -m leak
echo 'nothing here' > later.md; git add -A; git commit -q -m later
rc=0; run feat "$(git rev-parse HEAD)" "$ZERO" || rc=$?
expect_exit 1 "$rc" "new branch: secret below the tip commit blocks"
grep -q 'aws-access-key' "$T/err" && ok "match names the pattern" || bad "pattern name missing: $(cat "$T/err")"

# 2. New branch, commits already on the remote are not rescanned.
git checkout -q main; git checkout -q -b feat2
echo 'clean' > c.md; git add -A; git commit -q -m clean
rc=0; run feat2 "$(git rev-parse HEAD)" "$ZERO" || rc=$?
expect_exit 0 "$rc" "new clean branch passes"

# 3. Existing branch, incremental push with a secret: blocks.
git push -q origin feat2; PUSHED="$(git rev-parse HEAD)"
echo 'postgres://svc:sup3rs3cret@db/x' > d.md; git add -A; git commit -q -m leak2
rc=0; run feat2 "$(git rev-parse HEAD)" "$PUSHED" || rc=$?
expect_exit 1 "$rc" "incremental push with a secret blocks"

# 4. Redis form with no user segment is caught.
echo 'cache redis://:s3cretpass@cache.internal:6379' > e.md; git add -A; git commit -q -m leak3
rc=0; run feat2 "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)" || rc=$?
expect_exit 1 "$rc" "redis://:password@host blocks"

# 5. Remote sha the clone does not have: block, do not pass clean.
FAKE="$(printf 'a%.0s' {1..40})"
rc=0; run feat2 "$(git rev-parse HEAD)" "$FAKE" || rc=$?
expect_exit 1 "$rc" "unknown remote sha blocks instead of scanning nothing"
grep -q 'cannot diff' "$T/err" && ok "unknown remote sha is reported" || bad "no report: $(cat "$T/err")"

# 6. SENTINEL_SKIP bypass still works.
rc=0; SENTINEL_SKIP=1 run feat2 "$(git rev-parse HEAD)" "$FAKE" || rc=$?
expect_exit 0 "$rc" "SENTINEL_SKIP=1 bypasses"

echo; echo "passed: $pass  failed: $fail"
[[ $fail -eq 0 ]] || exit 1
