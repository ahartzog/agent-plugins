#!/usr/bin/env bash
set -euo pipefail

# Hermetic git: the user's global/system config must not leak into fixture
# repos — a globally-installed hook suite (core.hooksPath, e.g. ggshield)
# would otherwise intercept fixture pushes and fail setup unauthenticated.
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=apiary-test GIT_AUTHOR_EMAIL=test@example.invalid
export GIT_COMMITTER_NAME=apiary-test GIT_COMMITTER_EMAIL=test@example.invalid
# Exercises the Apiculturist (protocol/apiculturist-workflow.md).
#
# The Apiculturist is specified in prose; this test simulates the spec'd
# behavior with python against a fixture registry table and verifies:
#   1. A missing row is INSERTED alphabetically by slug (§2 step 2).
#   2. A drifted row is UPDATED, and only the drifted cells change (§2 step 3).
#   3. A current row triggers NO WRITE at all — idempotency (§2 step 3, the
#      invariant that keeps nightly Parliaments from churning page history).
#   4. Other Hives' rows stay byte-identical through an update (blast radius).
#   5. CUI renders as the purple `CUI / ITAR` cell (§3).
#   6. A legacy FOUO ceiling is preserved, never normalized to CUI/UNCLASSIFIED.
#   7. `CUI / ITAR` cell text parses back to the enum value `CUI` on pull (§1).
#   8. Unparseable classification text fails safe to UNCLASSIFIED (§1 step 2).
#   9. Spec invariants hold across the protocol docs (greps).
#
# Zero network: everything runs against the fixture below.
#
# Usage: bash apiculturist.test.sh

SKILL_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

fail=0
pass_count=0

report() {
  local ok="$1" desc="$2"
  if [[ "$ok" == "PASS" ]]; then
    echo "  PASS: $desc"
    pass_count=$((pass_count + 1))
  else
    echo "  FAIL: $desc"
    fail=1
  fi
}

# ----- Fixture: a three-row registry <tbody> in Confluence storage format -----
cat > "$TEST_ROOT/registry.xml" <<'EOF'
<table><tbody>
<tr><th>Hive</th><th>Purpose / What lives here</th><th>Repository</th><th>Max Classification</th><th>Owners</th><th>Slack</th><th>Apiary ver</th></tr>
<tr><td><a href="https://ghe.meridian.example/meridian/auth-hive">auth</a></td><td>Auth team knowledge</td><td><code>meridian/auth-hive</code></td><td class="highlight-#abf5d1" data-highlight-colour="#abf5d1" style="text-align: center;"><strong>UNCLASSIFIED</strong></td><td>asmith</td><td>#platform-auth-eng</td><td>2.0.2</td></tr>
<tr><td><a href="https://ghe.meridian.example/meridian/tracking-hive">tracking-hive</a></td><td>Object tracking and fusion</td><td><code>meridian/tracking-hive</code></td><td class="highlight-#abf5d1" data-highlight-colour="#abf5d1" style="text-align: center;"><strong>UNCLASSIFIED</strong></td><td>jchen</td><td>#tracking-pr</td><td>2.9.3</td></tr>
<tr><td><a href="https://ghe.meridian.example/meridian/vehicle-hive">vehicle-hive</a></td><td>Vehicle Integrations</td><td><code>meridian/vehicle-hive</code></td><td class="highlight-#998dd9" data-highlight-colour="#998dd9" style="text-align: center;"><strong>CUI / ITAR</strong></td><td>mrivera</td><td>#vehicle-hive</td><td>2.0.2</td></tr>
</tbody></table>
EOF

# ----- Simulation of the prose spec -----
cat > "$TEST_ROOT/apiculturist.py" <<'PYEOF'
"""Simulates protocol/apiculturist-workflow.md §1-§3 closely enough to test
the behaviors the spec asserts. Not shipped code — a spec harness."""
import re

ROW = re.compile(r'<tr>.*?</tr>', re.S)
CELL = re.compile(r'<t[dh][^>]*>(.*?)</t[dh]>', re.S)

# §1 step 2: cell text -> hive.schema.json enum. Unknown => UNCLASSIFIED (fail-safe).
PULL_MAP = {'UNCLASSIFIED': 'UNCLASSIFIED', 'CUI / ITAR': 'CUI', 'CUI': 'CUI',
            'FOUO (legacy)': 'FOUO', 'FOUO': 'FOUO'}

# §3: ceiling -> cell markup
PUSH_CELL = {
    'UNCLASSIFIED': '<td class="highlight-#abf5d1" data-highlight-colour="#abf5d1" style="text-align: center;"><strong>UNCLASSIFIED</strong></td>',
    'CUI':          '<td class="highlight-#998dd9" data-highlight-colour="#998dd9" style="text-align: center;"><strong>CUI / ITAR</strong></td>',
    'FOUO':         '<td class="highlight-#fff0b3" data-highlight-colour="#fff0b3" style="text-align: center;"><strong>FOUO (legacy)</strong></td>',
}

def strip_tags(s):
    return re.sub(r'<[^>]+>', '', s).strip()

def data_rows(body):
    """Data rows only — the header row uses <th>."""
    return [r for r in ROW.findall(body) if '<th>' not in r]

def slug_of(row):
    m = re.search(r'>([a-z0-9][a-z0-9-]*)</a>', CELL.findall(row)[0])
    return m.group(1) if m else None

def classification_of(row):
    return PULL_MAP.get(strip_tags(CELL.findall(row)[3]), 'UNCLASSIFIED')

def pull_roster(body, self_slug):
    """§1: parse every row except this Hive's."""
    out = []
    for r in data_rows(body):
        s = slug_of(r)
        if s == self_slug:
            continue
        cells = CELL.findall(r)
        out.append({'slug': s, 'purpose': strip_tags(cells[1]),
                    'repo': strip_tags(cells[2]), 'classification': classification_of(r)})
    return out

def build_row(h):
    org_repo = h['repo']
    return (
        '<tr>'
        f'<td><a href="https://ghe.meridian.example/{org_repo}">{h["slug"]}</a></td>'
        f'<td>{h["purpose"]}</td>'
        f'<td><code>{org_repo}</code></td>'
        f'{PUSH_CELL[h["max_level"]]}'
        f'<td>{h["owners"]}</td>'
        f'<td>#{h["slack"]}</td>'
        f'<td>{h["version"]}</td>'
        '</tr>'
    )

def upsert(body, h):
    """§2. Returns (new_body, action_string). new_body is body unchanged when
    nothing drifted — the caller MUST NOT write in that case."""
    mine = None
    for r in data_rows(body):
        if slug_of(r) == h['slug']:
            mine = r
            break

    if mine is None:
        new_row = build_row(h)
        rows = data_rows(body)
        after = None
        for r in rows:
            if slug_of(r) > h['slug']:
                after = r
                break
        if after is None:            # alphabetically last
            return body.replace('</tbody>', new_row + '\n</tbody>'), 'inserted'
        return body.replace(after, new_row + '\n' + after), 'inserted'

    cells = CELL.findall(mine)
    drift = []
    if strip_tags(cells[6]) != h['version']:
        drift.append(f'Apiary ver: {strip_tags(cells[6])}->{h["version"]}')
    if strip_tags(cells[1]) != h['purpose']:
        drift.append('Purpose')
    if strip_tags(cells[2]) != h['repo']:
        drift.append('Repository')
    if classification_of(mine) != h['max_level']:
        drift.append(f'Max Classification: {classification_of(mine)}->{h["max_level"]}')
    if strip_tags(cells[4]) != h['owners']:
        drift.append('Owners')
    if strip_tags(cells[5]) != '#' + h['slack']:
        drift.append('Slack')

    if not drift:
        return body, 'current'       # invariant: NO WRITE
    return body.replace(mine, build_row(h)), 'updated (' + ', '.join(drift) + ')'
PYEOF

echo "== Apiculturist spec simulation =="

run_py() {
  python3 - "$@" <<'PYEOF'
import sys, os
sys.path.insert(0, os.environ['TEST_ROOT'])
from apiculturist import *

body = open(os.environ['TEST_ROOT'] + '/registry.xml').read()
tracking_current = {'slug': 'tracking-hive', 'purpose': 'Object tracking and fusion',
                'repo': 'meridian/tracking-hive', 'max_level': 'UNCLASSIFIED',
                'owners': 'jchen', 'slack': 'tracking-pr', 'version': '2.9.3'}

case = sys.argv[1]

if case == 'insert':
    new = dict(tracking_current, slug='vault-hive', purpose='restricted programs',
               repo='restricted-org/vault-hive', max_level='CUI',
               owners='jchen', slack='proj-vault-hive', version='2.11.0')
    out, action = upsert(body, new)
    slugs = [slug_of(r) for r in data_rows(out)]
    print('action=' + action)
    print('order=' + ','.join(slugs))

elif case == 'update':
    bumped = dict(tracking_current, version='2.11.0')
    out, action = upsert(body, bumped)
    before, after = data_rows(body), data_rows(out)
    print('action=' + action)
    print('others_identical=' + str(before[0] == after[0] and before[2] == after[2]))
    print('ver_in_row=' + str('2.11.0' in [r for r in after if slug_of(r) == 'tracking-hive'][0]))

elif case == 'noop':
    out, action = upsert(body, tracking_current)
    print('action=' + action)
    print('body_unchanged=' + str(out == body))

elif case == 'cui_cell':
    new = dict(tracking_current, slug='zz-cui-hive', repo='restricted-org/zz', max_level='CUI')
    out, _ = upsert(body, new)
    row = [r for r in data_rows(out) if slug_of(r) == 'zz-cui-hive'][0]
    print('purple=' + str('highlight-#998dd9' in row))
    print('label=' + str('CUI / ITAR' in row))

elif case == 'fouo_preserved':
    new = dict(tracking_current, slug='zz-fouo', repo='meridian/zz', max_level='FOUO')
    out, _ = upsert(body, new)
    row = [r for r in data_rows(out) if slug_of(r) == 'zz-fouo'][0]
    print('yellow=' + str('highlight-#fff0b3' in row))
    print('label=' + str('FOUO (legacy)' in row))
    print('not_downgraded=' + str('UNCLASSIFIED' not in row and 'CUI' not in row))

elif case == 'pull_roundtrip':
    roster = pull_roster(body, 'tracking-hive')
    by = {r['slug']: r['classification'] for r in roster}
    print('self_excluded=' + str('tracking-hive' not in by))
    print('vehicle_is_CUI=' + str(by.get('vehicle-hive') == 'CUI'))
    print('auth_is_UNCLASS=' + str(by.get('auth') == 'UNCLASSIFIED'))
    print('count=' + str(len(roster)))

elif case == 'failsafe':
    weird = body.replace('<strong>CUI / ITAR</strong>', '<strong>Mystery Level</strong>')
    roster = pull_roster(weird, 'tracking-hive')
    by = {r['slug']: r['classification'] for r in roster}
    print('failsafe=' + str(by.get('vehicle-hive') == 'UNCLASSIFIED'))
PYEOF
}

export TEST_ROOT

# ----- 1. Insert a missing row, alphabetically -----
out="$(run_py insert)"
[[ "$out" == *"action=inserted"* ]] && report PASS "insert: missing row is inserted" || report FAIL "insert: missing row is inserted"
[[ "$out" == *"order=auth,tracking-hive,vault-hive,vehicle-hive"* ]] \
  && report PASS "insert: placed alphabetically by slug" \
  || { report FAIL "insert: placed alphabetically by slug"; echo "      got: $out"; }

# ----- 2. Update a drifted row -----
out="$(run_py update)"
[[ "$out" == *"action=updated (Apiary ver: 2.9.3->2.11.0)"* ]] \
  && report PASS "update: drift detected and named" \
  || { report FAIL "update: drift detected and named"; echo "      got: $out"; }
[[ "$out" == *"ver_in_row=True"* ]] && report PASS "update: new version written into row" || report FAIL "update: new version written into row"

# ----- 3. Blast radius: other rows untouched -----
[[ "$out" == *"others_identical=True"* ]] \
  && report PASS "update: other Hives' rows byte-identical" \
  || report FAIL "update: other Hives' rows byte-identical"

# ----- 4. Idempotency: no write when nothing drifted -----
out="$(run_py noop)"
[[ "$out" == *"action=current"* ]] && report PASS "noop: reports 'current'" || report FAIL "noop: reports 'current'"
[[ "$out" == *"body_unchanged=True"* ]] \
  && report PASS "noop: body byte-identical (no page write)" \
  || report FAIL "noop: body byte-identical (no page write)"

# ----- 5. CUI renders purple with the CUI / ITAR label -----
out="$(run_py cui_cell)"
[[ "$out" == *"purple=True"* && "$out" == *"label=True"* ]] \
  && report PASS "CUI: purple highlight + 'CUI / ITAR' label" \
  || { report FAIL "CUI: purple highlight + 'CUI / ITAR' label"; echo "      got: $out"; }

# ----- 6. Legacy FOUO preserved, never normalized away -----
out="$(run_py fouo_preserved)"
[[ "$out" == *"yellow=True"* && "$out" == *"label=True"* && "$out" == *"not_downgraded=True"* ]] \
  && report PASS "FOUO: yellow cell preserved, not rewritten to CUI/UNCLASSIFIED" \
  || { report FAIL "FOUO: yellow cell preserved, not rewritten"; echo "      got: $out"; }

# ----- 7. Pull round-trips cell text back to the schema enum -----
out="$(run_py pull_roundtrip)"
[[ "$out" == *"self_excluded=True"* ]] && report PASS "pull: own row excluded from roster" || report FAIL "pull: own row excluded from roster"
[[ "$out" == *"vehicle_is_CUI=True"* && "$out" == *"auth_is_UNCLASS=True"* ]] \
  && report PASS "pull: cell text normalizes to schema enum" \
  || { report FAIL "pull: cell text normalizes to schema enum"; echo "      got: $out"; }

# ----- 8. Unparseable classification fails safe -----
out="$(run_py failsafe)"
[[ "$out" == *"failsafe=True"* ]] \
  && report PASS "pull: unparseable ceiling fails safe to UNCLASSIFIED" \
  || report FAIL "pull: unparseable ceiling fails safe to UNCLASSIFIED"

# ----- 9. Spec invariants across the protocol docs -----
echo
echo "== Spec invariants =="

CUSTODIAN="$SKILL_ROOT/protocol/custodian-workflow.md"
AUDIT="$SKILL_ROOT/references/mode-audit.md"
UPGRADE="$SKILL_ROOT/references/mode-upgrade.md"
SPEC="$SKILL_ROOT/protocol/apiculturist-workflow.md"

grep -q 'work set is non-empty' "$CUSTODIAN" \
  && report FAIL "custodian: work-set gate removed from §1.4" \
  || report PASS "custodian: work-set gate removed from §1.4"

grep -q 'Dispatch the Apiculturist' "$CUSTODIAN" \
  && report PASS "custodian: §1.4 dispatches the Apiculturist" \
  || report FAIL "custodian: §1.4 dispatches the Apiculturist"

grep -q 'Step 4c: Registry Reconciliation Check' "$AUDIT" \
  && report PASS "audit: Step 4c present" \
  || report FAIL "audit: Step 4c present"

grep -q 'Migration: pre-2.5.0' "$UPGRADE" \
  && report PASS "upgrade: pre-2.5.0 backfill migration present" \
  || report FAIL "upgrade: pre-2.5.0 backfill migration present"

# Scope doc-invariant greps to the shipped protocol/references/assets, excluding
# tests/ — this file contains the very strings it is asserting are absent.
markup_copies="$(grep -rl 'highlight-#998dd9' "$SKILL_ROOT" --exclude-dir=tests | wc -l)"
[[ "$markup_copies" -eq 1 ]] \
  && report PASS "dedup: exactly one copy of the classification markup" \
  || { report FAIL "dedup: exactly one copy of the classification markup"; echo "      found $markup_copies"; }

grep -rq 'refreshed on operate' "$SKILL_ROOT" --exclude-dir=tests \
  && report FAIL "docs: no file claims the roster is 'refreshed on operate'" \
  || report PASS "docs: no file claims the roster is 'refreshed on operate'"

for inv in 'MUST NOT' 'NEVER'; do
  grep -q "$inv" "$SPEC" \
    && report PASS "spec: states $inv invariants" \
    || report FAIL "spec: states $inv invariants"
done

echo
echo "== Federation opt-outs =="

SCHEMA="$SKILL_ROOT/assets/hive.schema.json"
CREATE="$SKILL_ROOT/references/mode-create.md"
OPERATE="$SKILL_ROOT/references/mode-operate.md"

# Schema: both keys present, boolean, default true, and the block is closed.
if python3 - "$SCHEMA" <<'PYEOF'
import json, sys
f = json.load(open(sys.argv[1]))['properties']['federation']
assert f['additionalProperties'] is False, 'federation must be closed'
for k in ('register', 'cross_hive_routing'):
    assert f['properties'][k]['type'] == 'boolean', k
    assert f['properties'][k]['default'] is True, k + ' must default true'
PYEOF
then report PASS "schema: federation keys are boolean and default true"
else report FAIL "schema: federation keys are boolean and default true"; fi

# Omitting the block and all four matrix corners must validate; unknown keys must not.
if python3 - "$SCHEMA" <<'PYEOF'
import json, sys, jsonschema
s = json.load(open(sys.argv[1]))
# Build a minimal valid doc from the schema's own `required` list so this fixture
# cannot rot when required fields change.
vals = {'hive_slug': 'x-hive', 'description': 'd' * 20, 'upstream_version': '2.11.0',
        'remote': 'git@ghe.meridian.example:meridian/x-hive.git', 'default_branch': 'master',
        'persona': 'PROTOCOL/agent-definition.md', 'codeowners': ['jchen'],
        'slack_channel': 'x-hive'}
missing = [k for k in s['required'] if k not in vals]
assert not missing, 'fixture missing required fields: %s' % missing
base = {k: vals[k] for k in s['required']}
jsonschema.validate(base, s)                        # omitted => full participation
for r in (True, False):
    for c in (True, False):
        jsonschema.validate(dict(base, federation={'register': r, 'cross_hive_routing': c}), s)
try:
    jsonschema.validate(dict(base, federation={'register': True, 'bogus': 1}), s)
    raise SystemExit('unknown key was accepted')
except jsonschema.ValidationError:
    pass
PYEOF
then report PASS "schema: opt-out matrix validates, unknown key rejected"
else report FAIL "schema: opt-out matrix validates, unknown key rejected"; fi

# Every enforcement point must be gated, else an opt-out silently does nothing.
grep -q 'skip this step entirely' "$CUSTODIAN" \
  && report PASS "custodian: §1.4 skipped when both switches off" \
  || report FAIL "custodian: §1.4 skipped when both switches off"

grep -q 'federation.cross_hive_routing` is `false`' "$CUSTODIAN" \
  && report PASS "custodian: cross-hive fit check gated (§2.1)" \
  || report FAIL "custodian: cross-hive fit check gated (§2.1)"

grep -q 'federation.register' "$AUDIT" \
  && report PASS "audit: Step 4c honors opt-outs" \
  || report FAIL "audit: Step 4c honors opt-outs"

grep -q 'FEDERATION_REGISTER' "$CREATE" \
  && report PASS "create: Step 6 gated on register opt-out" \
  || report FAIL "create: Step 6 gated on register opt-out"

grep -q 'federation.cross_hive_routing' "$OPERATE" \
  && report PASS "operate: session-time advisory gated" \
  || report FAIL "operate: session-time advisory gated"

# register:false must never be read as "retract my row".
grep -q 'MUST NOT delete an already-published row' "$SPEC" \
  && report PASS "spec: register:false never deletes an existing row" \
  || report FAIL "spec: register:false never deletes an existing row"

# The switches must not be mistaken for a classification control.
grep -q 'not a security control' "$SPEC" \
  && report PASS "spec: opt-outs disclaimed as non-security controls" \
  || report FAIL "spec: opt-outs disclaimed as non-security controls"

echo
if [[ "$fail" -eq 0 ]]; then
  echo "ALL TESTS PASS ($pass_count assertions)"
else
  echo "FAILURES — see above ($pass_count passed)"
  exit 1
fi
