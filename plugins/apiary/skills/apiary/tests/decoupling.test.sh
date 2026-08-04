#!/usr/bin/env bash
# decoupling.test.sh — asserts the org-specific couplings removed in 3.0.0 stay removed.
# Usage: bash decoupling.test.sh [classification|notifications|federation|org-coupling|survivors]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # -> plugins/apiary
# Scope note: this guard only ever scans under plugins/apiary — it never reaches the repo
# root. Repo-root files (SECURITY.md, root CONTRIBUTING.md, root README.md, etc.) are outside
# its reach and must be checked by hand for the same coupling classes.
FAILED=0

# Historical records intentionally retain the old vocabulary; the guard itself
# names every forbidden term, so it must not scan itself.
EXCLUDES=(
  --exclude-dir=.git
  --exclude=CHANGELOG.md
  --exclude=BACKLOG.md
  --exclude=decoupling.test.sh
)

# residue_filter: reads grep hit-lines ("file:line:content") on stdin, and re-emits
# only the ones where $1 (the forbidden pattern) still matches AFTER every substring
# matching $2 (the allow pattern) has been stripped out of the line. This is what makes
# the allowlist substring-precise rather than line-precise: dropping the whole line on
# any allow-match would also hide a stray forbidden term appended to (or already
# sharing) a legitimate line — the exact gap a Task 7 review caught live (a "Slack
# notification" sentence appended to an allowlisted "Slack tokens" credentials line
# still passed under the old whole-line `grep -v` filter). Stripping only the
# allow-matched substrings and re-testing the residue closes that gap while still
# letting the fixed set of already-audited legitimate mentions through untouched.
residue_filter() {
  python3 -c '
import re, sys
pattern = re.compile(sys.argv[1], re.IGNORECASE)
allow = re.compile(sys.argv[2], re.IGNORECASE)
for line in sys.stdin:
    line = line.rstrip("\n")
    if not line:
        continue
    residue = allow.sub("", line)
    if pattern.search(residue):
        print(line)
' "$1" "$2"
}

# check_group: FAILs if $pattern matches anywhere under $ROOT (outside EXCLUDES).
# Optional $3 is an "allow" pattern — see residue_filter above for exactly how hits
# matching it are handled (substring removal + residue re-test, not a whole-line drop).
# This is how bare-word patterns (e.g. \bslack\b) coexist with a fixed, known set of
# legitimate mentions: the sweep pattern stays broad (so a NEW stray reference is still
# caught, even one sharing a line with legitimate content), and only the specific
# already-audited substrings are subtracted back out. It is not a suppression of the
# pattern — anything that doesn't match one of the allow-listed shapes still fails.
check_group() {
  local group="$1"; shift
  local pattern="$1"; shift
  local allow="${1:-}"
  local hits
  hits="$(grep -rniE "$pattern" "${EXCLUDES[@]}" "$ROOT" || true)"
  if [[ -n "$hits" && -n "$allow" ]]; then
    hits="$(printf '%s\n' "$hits" | residue_filter "$pattern" "$allow")"
  fi
  if [[ -n "$hits" ]]; then
    printf 'FAIL [%s] surviving references:\n%s\n\n' "$group" "$hits" >&2
    FAILED=1
  else
    printf 'PASS [%s]\n' "$group"
  fi
}

check_present() {
  local label="$1" file="$2" pattern="$3"
  if grep -qE "$pattern" "$ROOT/$file" 2>/dev/null; then
    printf 'PASS [survivors] %s\n' "$label"
  else
    printf 'FAIL [survivors] %s — expected %s in %s\n' "$label" "$pattern" "$file" >&2
    FAILED=1
  fi
}

VALID_GROUPS=(classification notifications federation org-coupling survivors)
WANT="${1:-all}"
if [[ "$WANT" != "all" ]]; then
  known=0
  for g in "${VALID_GROUPS[@]}"; do
    [[ "$WANT" == "$g" ]] && { known=1; break; }
  done
  if [[ "$known" -eq 0 ]]; then
    joined="$(IFS='|'; echo "${VALID_GROUPS[*]}")"
    printf 'decoupling.test.sh: unknown group "%s" (expected: all|%s)\n' "$WANT" "$joined" >&2
    exit 2
  fi
fi
run() { [[ "$WANT" == "all" || "$WANT" == "$1" ]]; }

run classification && check_group classification \
  'classification|\bCUI\b|\bFOUO\b|UNCLASSIFIED|\bITAR\b|marking_required|max_level|storage_tier'

# Bare \bslack\b closes the gap where the narrower patterns above (slack_channel,
# Signal bot, etc.) would miss a stray "Slack notification"/"post to Slack" reference
# entirely. The allow pattern is the fixed set of legitimate mentions audited in Task 7:
# the credential.slack-token detector (pattern + docs row + two test cases), the
# optional slack-cli connector (tool-tiers' row — including its "Commercial Slack"
# purpose text and "URL to slack" fallback text — plus DESIGN-GOALS and the
# Jira/Confluence/Slack connected-tier line), and prose mentions (security-policy's
# "Professional Slack handle" PII example and "Slack tokens" credential-list item,
# custodian-workflow's "Slack tokens" list, inbox-entry.schema.json's "Slack message
# timestamp" citation example, mode-create.md's "Slack channels" interview question).
# Each entry below is spliced directly into a Python regex alternation (residue_filter),
# not matched as a literal substring. Keep every entry regex-literal-safe — no unescaped
# metacharacters (., (, ), [, ], +, *, ?, etc.). An entry containing one would change what
# it matches out from under this list (e.g. over-stripping residue via a stray `.` or `(`),
# silently reopening the gap this allowlist was hardened to close. Escape any metacharacter
# that's genuinely part of the text you mean to allow.
SLACK_ALLOW='slack-cli|slack-token|Slack API token|Slack tokens|Slack handle|Jira boards, Slack channels|Slack message|Confluence/Slack|Commercial Slack|URL to slack'
run notifications && check_group notifications \
  'slack_channel|SLACK_CHANNEL|signal-bot|sw-signal|\.signal\b|Signal bot|Signal post|Signal Config|\bslack\b' \
  "$SLACK_ALLOW"

run federation && check_group federation \
  'confluence_registry|REGISTRY_URL|Hive Mind Registry|[Aa]piculturist|cross_hive|cross-hive|\bsiblings\b|federation'

# Bare \bmeridian\b closes the same class of gap: "Meridian Systems" never matches a
# stray bare "Meridian" mention that dropped the second word.
run org-coupling && check_group org-coupling \
  'Meridian Systems|claude-clams|ghe\.meridian|jira\.meridian|confluence\.meridian|docs\.meridian|meridian/owners|repo-provisioner|\bmeridian\b'

# Positive assertions: a future sweep that deletes the Sentinel triage runbook or thins
# the pattern file should fail loudly here, not slip through as an absence nobody checked.
if run survivors; then
  check_present "sentinel triage verb" \
    "skills/apiary/references/pre-push-sentinel.md" "classify each match"
  check_present "operate-mode triage pointer" \
    "skills/apiary/references/mode-operate.md" "diagnose-and-classify"
  check_present "override mechanism retained" \
    "skills/apiary/assets/generate-hook.sh" "_covered\(\)"
  n=$(python3 -c "import json;print(len(json.load(open('$ROOT/skills/apiary/assets/sentinel-patterns.json'))['patterns']))")
  [[ "$n" == "18" ]] && printf 'PASS [survivors] 18 sentinel patterns\n' \
    || { printf 'FAIL [survivors] sentinel pattern count is %s, expected 18\n' "$n" >&2; FAILED=1; }
fi

if [[ $FAILED -ne 0 ]]; then
  echo "decoupling.test.sh: FAILED" >&2
  exit 1
fi
echo "decoupling.test.sh: all groups pass"
