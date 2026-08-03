#!/usr/bin/env bash
# decoupling.test.sh — asserts the org-specific couplings removed in 3.0.0 stay removed.
# Usage: bash decoupling.test.sh [classification|notifications|federation|org-coupling]
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"   # -> plugins/apiary
FAILED=0

# Historical records intentionally retain the old vocabulary; the guard itself
# names every forbidden term, so it must not scan itself.
EXCLUDES=(
  --exclude-dir=.git
  --exclude=CHANGELOG.md
  --exclude=BACKLOG.md
  --exclude=decoupling.test.sh
)

check_group() {
  local group="$1"; shift
  local pattern="$1"
  local hits
  hits="$(grep -rniE "$pattern" "${EXCLUDES[@]}" "$ROOT" || true)"
  if [[ -n "$hits" ]]; then
    printf 'FAIL [%s] surviving references:\n%s\n\n' "$group" "$hits" >&2
    FAILED=1
  else
    printf 'PASS [%s]\n' "$group"
  fi
}

WANT="${1:-all}"
run() { [[ "$WANT" == "all" || "$WANT" == "$1" ]]; }

run classification && check_group classification \
  'classification|\bCUI\b|\bFOUO\b|UNCLASSIFIED|\bITAR\b|marking_required|max_level|storage_tier'

run notifications && check_group notifications \
  'slack_channel|SLACK_CHANNEL|signal-bot|sw-signal|\.signal/|Signal bot|Signal post|Signal Config'

run federation && check_group federation \
  'confluence_registry|REGISTRY_URL|Hive Mind Registry|[Aa]piculturist|cross_hive|cross-hive|^siblings:|federation'

run org-coupling && check_group org-coupling \
  'Meridian Systems|claude-clams|ghe\.meridian|jira\.meridian|confluence\.meridian|docs\.meridian|meridian/owners|repo-provisioner'

if [[ $FAILED -ne 0 ]]; then
  echo "decoupling.test.sh: FAILED" >&2
  exit 1
fi
echo "decoupling.test.sh: all groups pass"
