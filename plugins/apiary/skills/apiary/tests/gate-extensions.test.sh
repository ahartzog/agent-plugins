#!/usr/bin/env bash
set -euo pipefail
# Integration tests for Apiary gate extensions (extensions.gates).
#
# Validates: discovery from hive.yml, the type discriminator, allow/block,
# on_error semantics, required_tools fail-closed behavior, timeout handling,
# back-compat when no HIVE_ROOT is passed, and — the load-bearing one — that a
# gate can never suppress a built-in Sentinel match.
#
# Note: the hook under test is *expected* to exit non-zero in most cases here,
# so every invocation is explicitly guarded (`|| rc=$?`, `|| true`) rather than
# relying on `set -e` to be lenient.
#
# Usage: bash gate-extensions.test.sh [path-to-generate-hook.sh]
#   Defaults to ../assets/generate-hook.sh relative to this script.

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GEN="${1:-$HERE/../assets/generate-hook.sh}"
PATTERNS="$HERE/../assets/sentinel-patterns.json"

for f in "$GEN" "$PATTERNS"; do
  if [[ ! -f "$f" ]]; then
    echo "gate-extensions.test.sh: required file not found: $f" >&2
    exit 2
  fi
done

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass_count=0
fail_count=0

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
# Fixture: a Hive with one gate extension
# --------------------------------------------------------
HIVE="$TEST_ROOT/hive"
mkdir -p "$HIVE/PROTOCOL/extensions/gates" "$HIVE/_inbox" "$HIVE/scripts"
cd "$HIVE"
git init -q .
git config user.email test@example.com
git config user.name test

write_hive_yml() {  # $1 = value for extensions.gates
  cat > "$HIVE/hive.yml" <<EOF
hive_slug: test-hive
default_branch: master
extensions:
  workflows: null
  gates: $1
  knowledge_schema: null
auto_merge:
  tribunal_passed: true
EOF
}

write_gate() {  # $1=on_error $2=required_tools $3=timeout $4=command
  cat > "$HIVE/PROTOCOL/extensions/gates/demo-gate.md" <<EOF
---
layer: PROTOCOL
type: gate-extension
gate: demo-gate
command: $4
description: Demo gate used by the Apiary gate-extension test suite.
last_updated: 2026-07-30
codeowners: [tester]
on_error: $1
timeout_seconds: $3
required_tools: $2
---
body
EOF
}

regen() {  # $@ = extra args to generator
  bash "$GEN" "$PATTERNS" "$@" > "$HIVE/hook.sh" 2>"$TEST_ROOT/gen.err"
  chmod +x "$HIVE/hook.sh"
}

ZERO=0000000000000000000000000000000000000000
run_hook() {  # simulates git pre-push stdin; echoes exit code
  local sha rc=0
  sha="$(git -C "$HIVE" rev-parse HEAD)"
  printf 'refs/heads/master %s refs/heads/master %s\n' "$sha" "$ZERO" \
    | "$HIVE/hook.sh" origin . >"$TEST_ROOT/out" 2>&1 || rc=$?
  echo "$rc"
}

echo 'echo "gate ran with $# file(s)"; exit ${DEMO_RC:-0}' > "$HIVE/scripts/demo.sh"
printf -- '---\nauthor: t\n---\n\nclean body content\n' > "$HIVE/_inbox/2026-07-30-t-clean.md"
git -C "$HIVE" add -A >/dev/null; git -C "$HIVE" commit -qm init

# --------------------------------------------------------
# 1. Back-compat: no HIVE_ROOT arg -> zero gates
# --------------------------------------------------------
write_hive_yml "PROTOCOL/extensions/gates/"
write_gate block "[bash]" 0 "bash scripts/demo.sh"
regen
assert_contains '^GATE_COUNT=0$' "$HIVE/hook.sh" "no HIVE_ROOT arg: emits zero gates (back-compat)"

# --------------------------------------------------------
# 2. Discovery: gates baked in when HIVE_ROOT passed
# --------------------------------------------------------
regen "$HIVE"
assert_contains '^GATE_COUNT=1$' "$HIVE/hook.sh" "HIVE_ROOT passed: gate discovered"
assert_contains "^GATES=\\( \\\$'demo-gate" "$HIVE/hook.sh" "gate name baked in"

# --------------------------------------------------------
# 3. gates: null -> no gates discovered
# --------------------------------------------------------
write_hive_yml "null"
regen "$HIVE"
assert_contains '^GATE_COUNT=0$' "$HIVE/hook.sh" "gates: null -> zero gates"
write_hive_yml "PROTOCOL/extensions/gates/"

# --------------------------------------------------------
# 4. type discriminator: non-gate files ignored
# --------------------------------------------------------
cat > "$HIVE/PROTOCOL/extensions/gates/not-a-gate.md" <<'EOF'
---
type: workflow-extension
gate: should-not-load
command: false
---
EOF
regen "$HIVE"
assert_contains '^GATE_COUNT=1$' "$HIVE/hook.sh" "file without type: gate-extension is ignored"
assert_not_contains 'should-not-load' "$HIVE/hook.sh" "ignored file's gate name not baked in"
rm "$HIVE/PROTOCOL/extensions/gates/not-a-gate.md"

# --------------------------------------------------------
# 5. Malformed gate (no command) is skipped with a warning
# --------------------------------------------------------
cat > "$HIVE/PROTOCOL/extensions/gates/broken.md" <<'EOF'
---
type: gate-extension
gate: broken-gate
---
EOF
regen "$HIVE"
assert_contains 'skipping .* needs both' "$TEST_ROOT/gen.err" "malformed gate warns at generation time"
assert_not_contains 'broken-gate' "$HIVE/hook.sh" "malformed gate not baked in"
rm "$HIVE/PROTOCOL/extensions/gates/broken.md"

# --------------------------------------------------------
# 6. Gate allows -> push allowed, gate actually ran
# --------------------------------------------------------
write_gate block "[bash]" 0 "bash scripts/demo.sh"
regen "$HIVE"
rc="$(run_hook)"
assert_exit 0 "$rc" "gate exit 0: push allowed"
assert_contains 'gate ran with 1 file' "$TEST_ROOT/out" "gate receives the candidate file list"

# --------------------------------------------------------
# 7. Gate blocks -> push blocked
# --------------------------------------------------------
echo 'echo "gate ran with $# file(s)"; exit 1' > "$HIVE/scripts/demo.sh"
rc="$(run_hook)"
assert_exit 1 "$rc" "gate non-zero: push blocked"
assert_contains 'demo-gate.*BLOCKED' "$TEST_ROOT/out" "block message names the gate"

# --------------------------------------------------------
# 8. on_error: warn -> non-zero gate does not block
# --------------------------------------------------------
write_gate warn "[bash]" 0 "bash scripts/demo.sh"
regen "$HIVE"
rc="$(run_hook)"
assert_exit 0 "$rc" "on_error warn: non-zero gate allowed"
assert_contains 'on_error: warn' "$TEST_ROOT/out" "warn path is reported, not silent"

# --------------------------------------------------------
# 9. Unknown on_error value normalizes to block (typo fails closed)
# --------------------------------------------------------
write_gate blokk "[bash]" 0 "bash scripts/demo.sh"
regen "$HIVE"
assert_contains '\\tblock\\t' "$HIVE/hook.sh" "invalid on_error normalizes to block"
assert_not_contains 'blokk' "$HIVE/hook.sh" "the typo itself is not baked in"

# --------------------------------------------------------
# 10. Missing required tool: block -> fails closed with actionable message
# --------------------------------------------------------
write_gate block "[definitely-not-installed-xyz]" 0 "bash scripts/demo.sh"
regen "$HIVE"
rc="$(run_hook)"
assert_exit 1 "$rc" "missing required tool + block: fails closed"
assert_contains 'missing required tool' "$TEST_ROOT/out" "missing tool message is actionable"

# --------------------------------------------------------
# 11. Missing required tool: warn -> skipped, push allowed
# --------------------------------------------------------
write_gate warn "[definitely-not-installed-xyz]" 0 "bash scripts/demo.sh"
regen "$HIVE"
rc="$(run_hook)"
assert_exit 0 "$rc" "missing required tool + warn: skipped"
assert_contains 'SKIPPED' "$TEST_ROOT/out" "skip is reported"

# --------------------------------------------------------
# 12. Timeout is enforced and honors on_error
# --------------------------------------------------------
if command -v timeout >/dev/null 2>&1; then
  echo 'sleep 10' > "$HIVE/scripts/demo.sh"
  write_gate block "[bash]" 1 "bash scripts/demo.sh"
  regen "$HIVE"
  rc="$(run_hook)"
  assert_exit 1 "$rc" "gate timeout + block: push blocked"
  assert_contains 'timed out' "$TEST_ROOT/out" "timeout is reported"
else
  echo "SKIP: timeout(1) unavailable — timeout test not run"
fi

# --------------------------------------------------------
# 13. THE INVARIANT: a permissive gate cannot rescue a Sentinel match
# --------------------------------------------------------
echo 'echo "permissive gate says OK"; exit 0' > "$HIVE/scripts/demo.sh"
write_gate block "[bash]" 0 "bash scripts/demo.sh"
regen "$HIVE"
printf -- '---\nauthor: t\n---\n\nAKIAIOSFODNN7EXAMPLE\n' > "$HIVE/_inbox/2026-07-30-t-dirty.md"
git -C "$HIVE" add -A >/dev/null; git -C "$HIVE" commit -qm dirty
rc="$(run_hook)"
assert_exit 1 "$rc" "INVARIANT: gate exit 0 cannot suppress a built-in Sentinel match"
assert_contains 'credential.aws-access-key' "$TEST_ROOT/out" "Sentinel match is what blocked"
assert_not_contains 'permissive gate says OK' "$TEST_ROOT/out" \
  "INVARIANT: gate is never invoked when the pattern scan fails"

# --------------------------------------------------------
# 14. scan / scan-dir do not run gates (recursion guard)
# --------------------------------------------------------
rm "$HIVE/_inbox/2026-07-30-t-dirty.md"
git -C "$HIVE" add -A >/dev/null; git -C "$HIVE" commit -qm rmdirty
echo 'echo "permissive gate says OK"; exit 0' > "$HIVE/scripts/demo.sh"
regen "$HIVE"
rc=0
"$HIVE/hook.sh" scan "$HIVE/_inbox/2026-07-30-t-clean.md" >"$TEST_ROOT/out" 2>&1 || rc=$?
assert_exit 0 "$rc" "scan mode: clean file passes"
assert_not_contains 'permissive gate says OK' "$TEST_ROOT/out" \
  "scan mode does not run gates (prevents gate->scan->gate recursion)"

rc=0
"$HIVE/hook.sh" scan-dir "$HIVE" >"$TEST_ROOT/out" 2>&1 || rc=$?
assert_exit 0 "$rc" "scan-dir mode: clean inbox passes"
assert_not_contains 'permissive gate says OK' "$TEST_ROOT/out" "scan-dir mode does not run gates"

# --------------------------------------------------------
# 15. Inline `#` comments in frontmatter are stripped
#
# Nothing in the schema or template forbids an inline comment, and each field
# failed differently and silently without the strip: timeout_seconds fell back
# to 0 (no timeout), and the `#` on command commented out the appended "$@" so
# the gate ran against zero files while still exiting 0.
# --------------------------------------------------------
echo 'echo "gate ran with $# file(s)"; exit 0' > "$HIVE/scripts/demo.sh"
cat > "$HIVE/PROTOCOL/extensions/gates/demo-gate.md" <<'EOF'
---
layer: PROTOCOL
type: gate-extension
gate: demo-gate
command: bash scripts/demo.sh # shells out to a model, can hang
description: Demo gate whose frontmatter carries inline comments.
last_updated: 2026-07-30
codeowners: [tester]
on_error: warn # advisory while we tune it
timeout_seconds: 120 # model call
required_tools: [bash] # nothing exotic
---
body
EOF
regen "$HIVE"
assert_contains '\\t120\\t' "$HIVE/hook.sh" "inline comment stripped from timeout_seconds"
assert_contains '\\twarn\\t' "$HIVE/hook.sh" "inline comment stripped from on_error"
assert_not_contains 'can hang|advisory|model call|nothing exotic' "$HIVE/hook.sh" \
  "no comment text survives into the generated hook"
rc="$(run_hook)"
assert_exit 0 "$rc" "gate with commented frontmatter still runs"
# The load-bearing one: a commented `command` used to swallow "$@", so the gate
# inspected nothing and passed anyway.
assert_not_contains 'gate ran with 0 file' "$TEST_ROOT/out" \
  "commented command still receives its candidate files"
assert_contains 'gate ran with [1-9]' "$TEST_ROOT/out" "gate saw at least one candidate file"

# --------------------------------------------------------
# 16. The foreign-hook marker has a single source of truth
#
# mode-operate.md Step 0 greps for this marker to decide whether a hook is ours.
# If the generator's literal and Step 0's literal ever diverged, every real
# Apiary hook would be misclassified as foreign and frozen against pattern
# updates behind nothing louder than a warning.
# --------------------------------------------------------
marker="$(bash "$GEN" --print-marker)"
if [[ -n "$marker" ]]; then
  echo "PASS: --print-marker emits a non-empty marker"; ((pass_count++)) || true
else
  echo "FAIL: --print-marker emitted nothing"; ((fail_count++)) || true
fi
if grep -qF -- "$marker" "$HIVE/hook.sh"; then
  echo "PASS: --print-marker matches the generated hook (single source of truth)"
  ((pass_count++)) || true
else
  echo "FAIL: --print-marker does not match the generated hook"; ((fail_count++)) || true
fi
# --print-marker takes no arguments, so it must work with no patterns file.
rc=0
bash "$GEN" --print-marker >/dev/null 2>&1 || rc=$?
assert_exit 0 "$rc" "--print-marker works without a patterns-file argument"

# --------------------------------------------------------
# Summary
# --------------------------------------------------------
echo ""
echo "---"
echo "Results: $pass_count passed, $fail_count failed"
if [[ "$fail_count" -eq 0 ]]; then
  echo "ALL TESTS PASS"
  exit 0
else
  echo "FAILURES — see above"
  exit 1
fi
