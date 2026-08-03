#!/usr/bin/env bash
set -euo pipefail
# Integration tests for the Apiary Sentinel pre-push hook.
#
# Validates: pattern matching, body-only scanning, override suppression,
# scan-dir mode, and error cases.
#
# Usage: bash sentinel.test.sh <path-to-hook>
#   Works with both the Python version (assets/sentinel-pre-push) and the
#   generated bash version. Run against Python first to establish baseline,
#   then against bash to confirm identical behavior.

if [[ $# -lt 1 ]]; then
  echo "Usage: bash sentinel.test.sh <path-to-hook>" >&2
  exit 2
fi

HOOK="$1"

if [[ ! -f "$HOOK" ]]; then
  echo "sentinel.test.sh: hook not found: $HOOK" >&2
  exit 2
fi

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

mkdir -p "$TEST_ROOT/_inbox"

fail_count=0
pass_count=0

assert_exit() {
  local expected="$1" actual="$2" desc="$3"
  if [[ "$actual" -eq "$expected" ]]; then
    echo "PASS: $desc"
    ((pass_count++)) || true
  else
    echo "FAIL: $desc — expected exit $expected, got $actual"
    ((fail_count++)) || true
  fi
}

assert_stderr_contains() {
  local pattern="$1" stderr_file="$2" desc="$3"
  if grep -qE "$pattern" "$stderr_file"; then
    echo "PASS: $desc"
    ((pass_count++)) || true
  else
    echo "FAIL: $desc — stderr did not contain: $pattern"
    echo "  stderr: $(cat "$stderr_file")"
    ((fail_count++)) || true
  fi
}

assert_stderr_not_contains() {
  local pattern="$1" stderr_file="$2" desc="$3"
  if ! grep -qE "$pattern" "$stderr_file"; then
    echo "PASS: $desc"
    ((pass_count++)) || true
  else
    echo "FAIL: $desc — stderr unexpectedly contained: $pattern"
    ((fail_count++)) || true
  fi
}

STDERR="$TEST_ROOT/stderr.tmp"

# --------------------------------------------------------
# Fixtures
# --------------------------------------------------------

cat > "$TEST_ROOT/_inbox/has-password.md" <<'EOF'
---
title: "Password test"
author: tester
date: 2026-06-01
tag: status
status: ready
---

Config: password = "hunter2secret"
EOF

cat > "$TEST_ROOT/_inbox/has-aws-key.md" <<'EOF'
---
title: "AWS key test"
author: tester
date: 2026-06-01
tag: status
status: ready
---

Use key AKIAIOSFODNN7EXAMPLE for access.
EOF

cat > "$TEST_ROOT/_inbox/has-ssn.md" <<'EOF'
---
title: "SSN test"
author: tester
date: 2026-06-01
tag: status
status: ready
---

Contact: SSN 123-45-6789 on file.
EOF

cat > "$TEST_ROOT/_inbox/has-private-key.md" <<'EOF'
---
title: "Private key test"
author: tester
date: 2026-06-01
tag: status
status: ready
---

-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA0Z3VS5JJcds3xHn/ygWep4PAtEsFHEMNfwS...
EOF

cat > "$TEST_ROOT/_inbox/has-github-pat.md" <<'EOF'
---
title: "GitHub PAT test"
author: tester
date: 2026-06-01
tag: status
status: ready
---

Set GITHUB_TOKEN=ghp_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef1234
EOF

cat > "$TEST_ROOT/_inbox/clean.md" <<'EOF'
---
title: "Clean file"
author: tester
date: 2026-06-01
tag: status
status: ready
---

This file has no credentials or PII. The word password alone is fine.
EOF

# Frontmatter contains a connection string — body is clean
cat > "$TEST_ROOT/_inbox/frontmatter-only.md" <<'EOF'
---
title: "Frontmatter cred"
author: tester
date: 2026-06-01
tag: status
status: ready
source_url: "postgres://admin:secretpass123@db.internal:5432/prod"
---

Nothing sensitive here in the body.
EOF

# Full override suppresses the one match
cat > "$TEST_ROOT/_inbox/has-override.md" <<'EOF'
---
title: "Overridden credential"
author: tester
date: 2026-06-01
tag: status
status: ready
sentinel_override:
  reviewed_by: tester
  reviewed_at: 2026-06-01T00:00:00Z
  patterns:
    - credential.password-literal
  justification: "Documentation example"
---

Set password = "example-placeholder-value" in config.
EOF

# Partial override: SSN overridden, password is NOT
cat > "$TEST_ROOT/_inbox/partial-override.md" <<'EOF'
---
title: "Partial override"
author: tester
date: 2026-06-01
tag: status
status: ready
sentinel_override:
  reviewed_by: tester
  reviewed_at: 2026-06-01T00:00:00Z
  patterns:
    - pii.ssn
  justification: "Fake SSN example"
---

password = "realcredential123" and SSN 123-45-6789
EOF

# Inline override format: patterns: [a, b]
cat > "$TEST_ROOT/_inbox/inline-override.md" <<'EOF'
---
title: "Inline override format"
author: tester
date: 2026-06-01
tag: status
status: ready
sentinel_override:
  reviewed_by: tester
  reviewed_at: 2026-06-01T00:00:00Z
  patterns: [credential.password-literal, credential.api-key-literal]
  justification: "Docs examples"
---

password = "not-a-real-credential"
api_key = "ABCDEFGHIJKLMNOP1234"
EOF

# --------------------------------------------------------
# Section 1: Pattern matching (scan mode)
# --------------------------------------------------------
echo ""
echo "=== Section 1: Pattern matching ==="
echo ""

"$HOOK" scan "$TEST_ROOT/_inbox/has-password.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "has-password: exits 1"
assert_stderr_contains "credential\.password-literal" "$STDERR" "has-password: reports pattern name"

"$HOOK" scan "$TEST_ROOT/_inbox/has-aws-key.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "has-aws-key: exits 1"
assert_stderr_contains "credential\.aws-access-key" "$STDERR" "has-aws-key: reports pattern name"

"$HOOK" scan "$TEST_ROOT/_inbox/has-ssn.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "has-ssn: exits 1"
assert_stderr_contains "pii\.ssn" "$STDERR" "has-ssn: reports pattern name"

"$HOOK" scan "$TEST_ROOT/_inbox/has-private-key.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "has-private-key: exits 1"
assert_stderr_contains "credential\.private-key-block" "$STDERR" "has-private-key: reports pattern name"

"$HOOK" scan "$TEST_ROOT/_inbox/has-github-pat.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "has-github-pat: exits 1"
assert_stderr_contains "credential\.github-pat" "$STDERR" "has-github-pat: reports pattern name"

"$HOOK" scan "$TEST_ROOT/_inbox/clean.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 0 "$rc" "clean: exits 0"

# Table-driven positives — every remaining pattern gets one detection test, so
# a regex typo in any of them cannot ship green.
positive_case() {
  local pname="$1" payload="$2"
  local f="$TEST_ROOT/_inbox/pat-$(echo "$pname" | tr './' '--').md"
  {
    printf -- '---\ntitle: "pattern positive"\nauthor: tester\ndate: 2026-06-01\ntag: status\nstatus: ready\n---\n\n'
    printf '%s\n' "$payload"
  } > "$f"
  "$HOOK" scan "$f" 2>"$STDERR" && rc=0 || rc=$?
  assert_exit 1 "$rc" "positive[$pname]: exits 1"
  assert_stderr_contains "$(echo "$pname" | sed 's/\./\\./g')" "$STDERR" "positive[$pname]: reports pattern name"
}

positive_case "credential.api-key-literal"  'api_key = "ABCDEFGHIJKLMNOP1234"'
positive_case "credential.token-literal"    'access_token = "abcdefghij1234567890ABCDEFGHIJ"'
positive_case "credential.aws-secret-key"   'aws_secret_access_key = "wJalrXUtnFEMIK7MDENGbPxRfiCYEXAMPLEKEY12"'
positive_case "credential.gcp-key-json"     '"private_key_id": "0123456789abcdef0123456789abcdef01234567"'
positive_case "credential.connection-string" 'db: postgres://svc:sup3rs3cretpass@db.internal:5432/prod'
positive_case "credential.slack-token"      'token xoxb-1234567890-abcdefghij'
positive_case "credential.slack-token"      'refresh xoxe-1-abcdefghij12345'
positive_case "pii.us-phone"                'Call 415-555-0123 for details.'
positive_case "credential.github-token-fine-grained" 'GITHUB_TOKEN=github_pat_11ABCDEFG0123456789abcdefghijklmnop'
positive_case "credential.github-token-oauth" 'token gho_ABCDEFGHIJKLMNOPQRSTUVWXYZabcdef1234'
positive_case "credential.azure-account-key" 'AccountKey=abcdefghijklmnopqrstuvwxyz0123456789ABCD=='
positive_case "credential.azure-sas-sig"    'https://acct.blob.core.windows.net/c/f.txt?sv=2024&sig=abcDEF0123456789abcDEF0123456789ab'
positive_case "credential.jwt"              'saw eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV'
positive_case "credential.bearer-header"    'Authorization: Bearer abc123def456ghi789jkl012'

# .txt sources are first-class text deposits (sources-policy) and scan too.
printf 'transcript line with password = "hunter2secret"\n' > "$TEST_ROOT/deposit.txt"
"$HOOK" scan "$TEST_ROOT/deposit.txt" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "txt source: exits 1 (no-frontmatter file scanned whole)"

# --------------------------------------------------------
# Section 2: Frontmatter scanning
# --------------------------------------------------------
echo ""
echo "=== Section 2: Frontmatter scanning ==="
echo ""

# A credential in a frontmatter scalar leaks exactly like one in the body.
"$HOOK" scan "$TEST_ROOT/_inbox/frontmatter-only.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "frontmatter-only: exits 1 (cred in frontmatter IS scanned)"
assert_stderr_contains "credential\.connection-string" "$STDERR" "frontmatter-only: reports connection-string"

# The sentinel_override block itself is excluded from the frontmatter scan —
# its recorded pattern names / excerpts must not re-trigger matches.
# (has-override.md carries an override block and a clean body; see Section 3.)

# --------------------------------------------------------
# Section 3: Override suppression
# --------------------------------------------------------
echo ""
echo "=== Section 3: Override suppression ==="
echo ""

"$HOOK" scan "$TEST_ROOT/_inbox/has-override.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 0 "$rc" "full override: exits 0"

"$HOOK" scan "$TEST_ROOT/_inbox/partial-override.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "partial override: exits 1 (password not covered)"
assert_stderr_contains "credential\.password-literal" "$STDERR" "partial override: password pattern reported"
assert_stderr_not_contains "pii\.ssn" "$STDERR" "partial override: SSN suppressed"

"$HOOK" scan "$TEST_ROOT/_inbox/inline-override.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 0 "$rc" "inline override [a,b] format: exits 0 (legacy file-wide — no matches: recorded)"

# Excerpt-bound override: matches: pins the override to recorded line content.
# The recorded excerpt is covered; a NEW match of the same pattern on another
# line is NOT — the file-wide blind spot is closed.
cat > "$TEST_ROOT/_inbox/bound-override.md" <<'EOF2'
---
title: "Excerpt-bound override"
author: tester
date: 2026-06-01
tag: status
status: ready
sentinel_override:
  reviewed_by: tester
  reviewed_at: 2026-06-01T00:00:00Z
  patterns:
    - credential.password-literal
  matches:
    - 'password = "example-placeholder-value"'
  justification: "Documentation example"
---

Set password = "example-placeholder-value" in config.
Also set password = "aRealLeakedSecret99" somewhere else.
EOF2

# Inline-array matches form parses identically to the block form.
cat > "$TEST_ROOT/_inbox/bound-inline.md" <<'EOF2'
---
title: "Inline matches form"
author: tester
date: 2026-06-01
tag: status
status: ready
sentinel_override:
  reviewed_by: tester
  reviewed_at: 2026-06-01T00:00:00Z
  patterns: [credential.password-literal]
  matches: ['password = "example-placeholder-value"']
  justification: "Docs example"
---

Set password = "example-placeholder-value" in config.
Also password = "anotherRealSecret42" nearby.
EOF2
"$HOOK" scan "$TEST_ROOT/_inbox/bound-inline.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "inline matches: [..] form: still blocks the uncovered line"
assert_stderr_not_contains "example-placeholder-value" "$STDERR" "inline matches form: recorded excerpt suppressed"

"$HOOK" scan "$TEST_ROOT/_inbox/bound-override.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "bound override: exits 1 (new match of same pattern not covered)"
assert_stderr_contains "aRealLeakedSecret99" "$STDERR" "bound override: the uncovered line is the one reported"
assert_stderr_not_contains "example-placeholder-value" "$STDERR" "bound override: the recorded excerpt stays suppressed"

# --------------------------------------------------------
# Section 4: scan-dir mode
# --------------------------------------------------------
echo ""
echo "=== Section 4: scan-dir mode ==="
echo ""

"$HOOK" scan-dir "$TEST_ROOT" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 1 "$rc" "scan-dir: exits 1 (directory has violations)"
assert_stderr_contains "has-password\.md" "$STDERR" "scan-dir: reports has-password.md"
assert_stderr_contains "has-aws-key\.md" "$STDERR" "scan-dir: reports has-aws-key.md"

"$HOOK" scan-dir "$TEST_ROOT/nonexistent" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 2 "$rc" "scan-dir nonexistent: exits 2"

NO_INBOX="$TEST_ROOT/no-inbox"
mkdir -p "$NO_INBOX"
"$HOOK" scan-dir "$NO_INBOX" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 2 "$rc" "scan-dir no-inbox/: exits 2"

# --------------------------------------------------------
# Section 5: Error cases
# --------------------------------------------------------
echo ""
echo "=== Section 5: Error cases ==="
echo ""

"$HOOK" scan "$TEST_ROOT/_inbox/nonexistent.md" 2>"$STDERR" && rc=0 || rc=$?
assert_exit 2 "$rc" "scan nonexistent file: exits 2"

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
