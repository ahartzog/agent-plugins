#!/usr/bin/env bash
set -euo pipefail
# Exercises the Frontmatter Normalizer (custodian-workflow.md Step 2.0).
#
# The normalizer is specified in prose; this test simulates the spec'd
# behavior with python and verifies:
#   1. Alt fields (contributor, contributed_by, session_date, type) get
#      canonical equivalents (author, date, tag) added alongside.
#   2. status: ready is inferred when author+date+tag/type are all present.
#   3. Existing canonical fields are NEVER overwritten.
#   4. Files lacking both author-equivalent and date-equivalent are skipped.
#   5. The schema_normalized timestamp is added when normalization fires.
#
# Usage: bash normalizer.test.sh

TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

cd "$TEST_ROOT"

# ----- Fixture: alt-schema file lacking status -----
mkdir -p _inbox
cat > _inbox/alt-schema-1.md <<'EOF'
---
title: "SITL/HITL stack contexts and active disagreement — May 2026"
type: discovery
contributed_by: jrivera
session_date: 2026-05-17
confidence: high
---

# Body content
EOF

# ----- Fixture: contributor + type:decision -----
cat > _inbox/alt-schema-2.md <<'EOF'
---
title: "AuthX password length STIG requirement"
contributor: jrivera
date: 2026-05-07
type: decision
---
EOF

# ----- Fixture: canonical (should be left alone) -----
cat > _inbox/canonical.md <<'EOF'
---
author: jrivera
date: 2026-05-18
tag: status
status: ready
---
EOF

# ----- Fixture: canonical with conflicting alt — must NOT be overwritten -----
cat > _inbox/conflict.md <<'EOF'
---
author: jrivera-canonical
contributor: someone-else
date: 2026-05-18
tag: status
status: ready
---
EOF

# ----- Fixture: too-ambiguous (no author-equivalent) -----
cat > _inbox/ambiguous.md <<'EOF'
---
title: "Just a title"
type: discovery
---
EOF

# ----- Run the normalizer (reference implementation in python) -----
python3 - <<'PY'
import re, os, datetime
from pathlib import Path

ALT_AUTHOR = ("contributor", "contributed_by")
ALT_DATE = ("session_date",)
TYPE_TO_TAG = {
    "discovery": "status",
    "decision": "process",
    "correction": "correction",
    "architecture": "architecture",
    "link": "link",
    "person": "person",
    "tracker": "tracker",
    "contradiction": "contradiction",
    "strategy": "strategy",
    "meta": "meta",
}
TODAY = datetime.date.today().isoformat()

def parse_fm(text):
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, None
    fm_text = m.group(1)
    fm = {}
    for line in fm_text.splitlines():
        if ":" in line and not line.startswith(" "):
            k, _, v = line.partition(":")
            fm[k.strip()] = v.strip()
    return fm, m.end()

def render_fm(fm):
    return "---\n" + "\n".join(f"{k}: {v}" for k, v in fm.items()) + "\n---\n"

for path in sorted(Path("_inbox").glob("*.md")):
    text = path.read_text()
    fm, fm_end = parse_fm(text)
    if fm is None:
        continue
    body = text[fm_end:]
    original = dict(fm)
    any_change = False
    tag_inferred = False

    # Alias author
    if "author" not in fm:
        for k in ALT_AUTHOR:
            if k in fm:
                fm["author"] = fm[k]; any_change = True; break

    # Alias date
    if "date" not in fm:
        for k in ALT_DATE:
            if k in fm:
                fm["date"] = fm[k]; any_change = True; break

    # Alias tag from type
    if "tag" not in fm:
        t = fm.get("type", "").strip().lower()
        if t in TYPE_TO_TAG:
            fm["tag"] = TYPE_TO_TAG[t]; any_change = True; tag_inferred = True

    # Infer status: ready when all canonical fields are present
    if "status" not in fm and all(k in fm for k in ("author", "date", "tag")):
        fm["status"] = "ready"; any_change = True

    # Skip if too ambiguous (no author-equivalent)
    if "author" not in fm:
        continue

    if any_change:
        # schema_normalized stamps only when tag was inferred (spec Step 4)
        if tag_inferred:
            fm.setdefault("schema_normalized", TODAY)
        path.write_text(render_fm(fm) + body)
PY

# ----- Assertions -----
fail=0
assert_grep() {
  local file="$1" pattern="$2" desc="$3"
  if grep -qE "$pattern" "$file"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc — file=$file pattern=$pattern"
    fail=1
  fi
}
assert_no_grep() {
  local file="$1" pattern="$2" desc="$3"
  if ! grep -qE "$pattern" "$file"; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc — file=$file pattern=$pattern"
    fail=1
  fi
}

# alt-schema-1: contributed_by → author, session_date → date, type:discovery → tag:status, status:ready inferred
assert_grep _inbox/alt-schema-1.md '^author: jrivera' "alt-1: author added from contributed_by"
assert_grep _inbox/alt-schema-1.md '^date: 2026-05-17' "alt-1: date added from session_date"
assert_grep _inbox/alt-schema-1.md '^tag: status' "alt-1: tag added from type:discovery"
assert_grep _inbox/alt-schema-1.md '^status: ready' "alt-1: status:ready inferred"
assert_grep _inbox/alt-schema-1.md '^contributed_by: jrivera' "alt-1: original contributed_by preserved"
assert_grep _inbox/alt-schema-1.md '^schema_normalized: ' "alt-1: schema_normalized stamp added"

# alt-schema-2: contributor → author, type:decision → tag:process, status:ready inferred
assert_grep _inbox/alt-schema-2.md '^author: jrivera' "alt-2: author added from contributor"
assert_grep _inbox/alt-schema-2.md '^tag: process' "alt-2: tag:process from type:decision"
assert_grep _inbox/alt-schema-2.md '^status: ready' "alt-2: status:ready inferred"

# canonical: untouched (no schema_normalized stamp)
assert_no_grep _inbox/canonical.md '^schema_normalized:' "canonical: NOT stamped"

# conflict: existing canonical author preserved, NOT overwritten by contributor
assert_grep _inbox/conflict.md '^author: jrivera-canonical' "conflict: canonical author preserved"
assert_no_grep _inbox/conflict.md '^author: someone-else' "conflict: alt did NOT clobber canonical"

# ambiguous: no author-equivalent → not normalized → no canonical fields added
assert_no_grep _inbox/ambiguous.md '^author:' "ambiguous: skipped (no author-equivalent)"

if [[ "$fail" -eq 0 ]]; then
  echo
  echo "ALL TESTS PASS"
else
  echo
  echo "FAILURES — see above"
  exit 1
fi
