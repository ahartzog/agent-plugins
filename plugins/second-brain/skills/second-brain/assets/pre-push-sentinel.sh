#!/usr/bin/env bash
# pre-push-sentinel.sh — git pre-push hook: blocks pushes whose outgoing
# commits ADD lines matching credential/PII patterns.
#
# Why: a vault that auto-pushes on a timer (Obsidian Git plugin, launchd cron)
# commits and pushes with no human in the loop. This is the last gate before
# a leaked credential or SSN leaves the machine.
#
# Bypass a confirmed false positive:  SENTINEL_SKIP=1 git push
# Fail-open: any script error exits 0 — a broken hook must never block work.
#
# Install (git hooks are NOT versioned, so this must be linked per-clone):
#   ln -sf ../../.claude/hooks/pre-push-sentinel.sh .git/hooks/pre-push
# Better: have a SessionStart hook self-install the symlink so a fresh clone
# is protected without a manual step (see references/enforcement-hooks.md).

[ "${SENTINEL_SKIP:-0}" = "1" ] && exit 0
VAULT="$(git rev-parse --show-toplevel 2>/dev/null)" || exit 0
PATTERNS="$VAULT/.claude/hooks/sentinel-patterns.json"
[ -f "$PATTERNS" ] || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

STATUS=0
while read -r _local_ref local_sha _remote_ref remote_sha; do
  [ -z "$local_sha" ] && continue
  case "$local_sha" in *[!0]*) ;; *) continue ;; esac
  if printf '%s' "$remote_sha" | grep -q '[^0]'; then
    RANGE="$remote_sha..$local_sha"
  else
    RANGE="$local_sha -1"   # new remote ref: scan the tip commit only
  fi
  git log $RANGE --format= --unified=0 -p 2>/dev/null | grep '^+' | \
  python3 -c '
import json, re, sys
try:
    patterns = [(p["name"], re.compile(p["regex"]))
                for p in json.load(open(sys.argv[1]))["patterns"]]
    hits = []
    for line in sys.stdin:
        for name, rx in patterns:
            if rx.search(line):
                hits.append((name, line.strip()[:120]))
    if hits:
        print("\nsentinel: push BLOCKED — outgoing commits add lines matching "
              "credential/PII patterns:", file=sys.stderr)
        for name, frag in hits[:10]:
            print("  [%s] %s" % (name, frag), file=sys.stderr)
        print("Fix the content, or bypass a confirmed false positive with: "
              "SENTINEL_SKIP=1 git push", file=sys.stderr)
        sys.exit(1)
except SystemExit:
    raise
except Exception:
    sys.exit(0)  # fail-open
' "$PATTERNS" || STATUS=1
done
exit $STATUS
