#!/usr/bin/env bash
set -euo pipefail
# Golden-case exercises for the Reference Library Discovery Protocol
# (protocol/routing-protocol.md) and its companion schemas.
#
# HONESTY NOTE — read before trusting a green run:
#
#   Part A (always runs, deterministic, CI-safe) verifies the FIXTURES in
#   tests/golden/ are shaped the way tests/golden/cases.md claims they are —
#   e.g. "the authority-conflict catalog really does have one `formal` row
#   and one `working` row on the same topic," "the broken-pointer catalog
#   really does lack sources[]." These are grep/awk checks against static
#   markdown. They prove the test bed is not rotted. They do NOT prove an
#   agent reading the protocol behaves correctly against it.
#
#   Part B (opt-in via APIARY_GOLDEN_LLM_JUDGE=1) is what actually exercises
#   agent behavior: it hands each case's prompt from cases.md to a real
#   `claude -p` subagent and applies keyword heuristics to the transcript.
#   This is NOT a rigorous grader — a correct answer phrased unexpectedly
#   can read as a false failure, and a confidently-wrong answer that happens
#   to contain the right keywords can read as a false pass. Treat Part B
#   output as a triage signal, not a verdict; read the saved transcripts
#   for anything it flags FAIL. It is opt-in specifically so CI (which runs
#   Part A on every PR) never depends on live model calls, quota, or
#   non-determinism.
#
# Usage:
#   bash golden-routing.test.sh                       # Part A only
#   APIARY_GOLDEN_LLM_JUDGE=1 bash golden-routing.test.sh   # Part A + Part B
#   APIARY_GOLDEN_LLM_TIMEOUT=180 APIARY_GOLDEN_LLM_JUDGE=1 bash golden-routing.test.sh
#     # per-case timeout in seconds for the `claude -p` call, default 120

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GOLDEN_DIR="$SCRIPT_DIR/golden"
KNOWLEDGE_DIR="$GOLDEN_DIR/knowledge"
CASES_MD="$GOLDEN_DIR/cases.md"

if [[ ! -d "$GOLDEN_DIR" ]]; then
  echo "golden-routing.test.sh: fixture directory not found: $GOLDEN_DIR" >&2
  exit 2
fi

PASS=0
FAIL=0

check() {
  local desc="$1" cond="$2"
  if [[ "$cond" == "0" ]]; then
    echo "PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"
    FAIL=$((FAIL + 1))
  fi
}

grep_row() {
  # grep_row <file> <needle> — 0 if a line in <file> contains <needle>
  grep -qF "$2" "$1" 2>/dev/null && echo 0 || echo 1
}

echo "=============================================="
echo "Part A: deterministic fixture-structure checks"
echo "=============================================="
echo ""

# --- Fixture inventory: every knowledge-relative path cases.md cites exists ---
# Scoped to the known knowledge/ subdirectory prefixes used by this fixture set, so
# protocol-file cross-references (routing-protocol.md, references/mode-audit.md, etc.,
# which live outside knowledge/ entirely) are not misread as broken knowledge pointers.
echo "--- Fixture inventory (cases.md ↔ knowledge/) ---"
KNOWLEDGE_PREFIXES='ground-segment/|program/|people/'

while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  if [[ -f "$KNOWLEDGE_DIR/$rel" ]]; then
    check "cases.md references existing file: $rel" 0
  else
    check "cases.md references existing file: $rel" 1
  fi
done < <(grep -oE "\`(${KNOWLEDGE_PREFIXES})[a-zA-Z0-9_./-]+\.md\`" "$CASES_MD" | tr -d '`' | sort -u)

if grep -qF '`reference-library.md`' "$CASES_MD" || grep -qF 'knowledge/reference-library.md' "$CASES_MD"; then
  check "cases.md references existing file: reference-library.md" \
    "$([[ -f "$KNOWLEDGE_DIR/reference-library.md" ]] && echo 0 || echo 1)"
fi

# Directory pointers: backticked, end in '/', scoped the same way.
while IFS= read -r rel; do
  [[ -z "$rel" ]] && continue
  if [[ -d "$KNOWLEDGE_DIR/$rel" ]] && find "$KNOWLEDGE_DIR/$rel" -maxdepth 1 -name '*.md' | grep -q .; then
    check "cases.md references non-empty directory pointer: $rel" 0
  else
    check "cases.md references non-empty directory pointer: $rel" 1
  fi
done < <(grep -oE "\`(${KNOWLEDGE_PREFIXES})[a-zA-Z0-9_./-]+/\`" "$CASES_MD" | tr -d '`' | sort -u)

echo ""
echo "--- Case 1: one-hop local ---"
check "reference-library.md routes to program/overview.md" \
  "$(grep_row "$KNOWLEDGE_DIR/reference-library.md" 'program/overview.md')"
OVERVIEW_SOURCES_COUNT=$(grep -c '^sources:' "$KNOWLEDGE_DIR/program/overview.md" || true)
check "program/overview.md has no sources[] (nothing to fetch)" \
  "$([[ "${OVERVIEW_SOURCES_COUNT:-0}" -eq 0 ]] && echo 0 || echo 1)"

echo ""
echo "--- Case 2: authority conflict ---"
DOC_CATALOG="$KNOWLEDGE_DIR/ground-segment/document-catalog.md"
check "document-catalog.md declares a sharepoint store root" \
  "$(grep_row "$DOC_CATALOG" 'type: sharepoint')"
check "document-catalog.md has a formal row on link margin requirements" \
  "$([[ $(grep -c 'link margin requirements' "$DOC_CATALOG") -ge 2 ]] && echo 0 || echo 1)"
check "  ...one row is authority: formal" \
  "$(grep -F 'link margin requirements' "$DOC_CATALOG" | grep -qF '| formal |' && echo 0 || echo 1)"
check "  ...one row is authority: working" \
  "$(grep -F 'link margin requirements' "$DOC_CATALOG" | grep -qF '| working |' && echo 0 || echo 1)"
WORKING_LINE=$(awk '/link margin requirements/ && /\| working \|/ {print NR; exit}' "$DOC_CATALOG")
FORMAL_LINE=$(awk '/link margin requirements/ && /\| formal \|/ {print NR; exit}' "$DOC_CATALOG")
check "  ...working row sorts BEFORE formal row (guards against a row-order confound)" \
  "$([[ -n "$WORKING_LINE" && -n "$FORMAL_LINE" && "$WORKING_LINE" -lt "$FORMAL_LINE" ]] && echo 0 || echo 1)"

echo ""
echo "--- Case 3: store-relative folder row ---"
check "document-catalog.md has the Ground MTP Draft row" \
  "$(grep_row "$DOC_CATALOG" 'Ground MTP Draft')"
check "  ...Location cell is a folder (trailing slash), not an absolute URL" \
  "$(grep -F 'Ground MTP Draft' "$DOC_CATALOG" | grep -qF 'Working Docs/' && echo 0 || echo 1)"
check "  ...file declares a store root to resolve against (Case 3 requires one; contrast Case 4)" \
  "$(grep_row "$DOC_CATALOG" 'url: "https://example.sharepoint.us')"

echo ""
echo "--- Case 4: missing store root ---"
BROKEN_CATALOG="$KNOWLEDGE_DIR/ground-segment/broken-catalog.md"
check "broken-catalog.md declares NO sources[] block" \
  "$([[ $(grep -c '^sources:' "$BROKEN_CATALOG") -eq 0 ]] && echo 0 || echo 1)"
check "broken-catalog.md still has a store-relative row (the point of the fixture)" \
  "$(grep_row "$BROKEN_CATALOG" 'Legacy Command Format Register')"

echo ""
echo "--- Case 5: ID-addressed store ---"
ID_CATALOG="$KNOWLEDGE_DIR/program/id-store-catalog.md"
check "id-store-catalog.md row Location is an absolute quip.com URL" \
  "$(grep -F 'IPT Decision Log' "$ID_CATALOG" | grep -qF 'https://example.quip.com/' && echo 0 || echo 1)"
check "id-store-catalog.md declares type: quip" \
  "$(grep_row "$ID_CATALOG" 'type: quip')"

echo ""
echo "--- Case 6: covers absent ---"
check "document-catalog.md has the filename-only CDR row" \
  "$(grep_row "$DOC_CATALOG" 'CDR Ground Segment Design')"
check "  ...its covers cell is empty (no topical text to match on)" \
  "$(grep -F 'CDR Ground Segment Design' "$DOC_CATALOG" | grep -qE '\| *\| analysis-report \|' && echo 0 || echo 1)"

echo ""
echo "--- Case 7: covers sufficient, no fetch ---"
check "document-catalog.md RF Interface Requirements row covers names EIRP thresholds" \
  "$(grep -F 'PROJ-123 Ground Station RF Interface Requirements' "$DOC_CATALOG" | grep -qF 'EIRP thresholds' && echo 0 || echo 1)"

echo ""
echo "--- Case 8: tool missing → degradation ---"
VENDOR_CATALOG="$KNOWLEDGE_DIR/program/vendor-deliverable-catalog.md"
check "vendor-deliverable-catalog.md declares type: box" \
  "$(grep_row "$VENDOR_CATALOG" 'type: box')"
check "  ...row Location is an absolute app.box.com URL" \
  "$(grep -F 'Demo Corp CDR Chart Package' "$VENDOR_CATALOG" | grep -qF 'https://example.app.box.com/' && echo 0 || echo 1)"

echo ""
echo "--- Case 9: mixed-store catalog, partial root (optional extra) ---"
MIXED_CATALOG="$KNOWLEDGE_DIR/program/mixed-store-catalog.md"
check "mixed-store-catalog.md declares exactly one store root (sharepoint)" \
  "$([[ $(grep -c '^[[:space:]]*- url:' "$MIXED_CATALOG") -eq 1 ]] && echo 0 || echo 1)"
check "  ...yet has a row pointing at a second, undeclared store (github.com)" \
  "$(grep_row "$MIXED_CATALOG" 'github.com/example-org')"

echo ""
echo "--- Case 15: sources/ read path (Hive-root locator + verbatim fall-through) ---"
SRC_INDEX="$GOLDEN_DIR/sources/index.md"
SRC_TRANSCRIPT="$GOLDEN_DIR/sources/meeting-transcripts/2026-07-15-jrivera-link-budget-sync.md"
LB_NOTES="$KNOWLEDGE_DIR/ground-segment/link-budget-notes.md"
check "sources/index.md exists at the HIVE ROOT (not under knowledge/)" \
  "$([[ -f "$SRC_INDEX" ]] && echo 0 || echo 1)"
# The trap this whole feature exists to fix: the prescribed router token is `sources/index.md`,
# and the pre-2.24.0 §Resolve rule sent it to knowledge/sources/index.md. Assert that path is
# absent, so a future "helpful" fixture cannot mask the regression by creating it.
check "  ...and knowledge/sources/index.md does NOT exist (the mis-resolution target)" \
  "$([[ ! -e "$KNOWLEDGE_DIR/sources/index.md" ]] && echo 0 || echo 1)"
check "reference-library.md carries the prescribed \`sources/index.md\` router row" \
  "$(grep -qF '`sources/index.md`' "$KNOWLEDGE_DIR/reference-library.md" && echo 0 || echo 1)"
check "source index row points at the deposited transcript" \
  "$(grep -qF 'meeting-transcripts/2026-07-15-jrivera-link-budget-sync.md' "$SRC_INDEX" && echo 0 || echo 1)"
check "transcript exists and states the exact committed value (4.7 dB)" \
  "$([[ -f "$SRC_TRANSCRIPT" ]] && grep -qF '4.7 dB' "$SRC_TRANSCRIPT" && echo 0 || echo 1)"
check "knowledge paraphrase is topically responsive (mentions link margin)" \
  "$(grep -qi 'link margin' "$LB_NOTES" && echo 0 || echo 1)"
# Without this the case is untestable: if the paraphrase also carried 4.7, answering from the
# wrong file would be indistinguishable from answering from the source.
check "  ...but does NOT contain 4.7 — answering from it is detectably wrong" \
  "$(grep -qF '4.7' "$LB_NOTES" && echo 1 || echo 0)"
check "  ...and cites the transcript in sources[] (Goal 9 discoverability, second mechanism)" \
  "$(grep -qF 'sources/meeting-transcripts/2026-07-15-jrivera-link-budget-sync.md' "$LB_NOTES" && echo 0 || echo 1)"

echo ""
echo "--- Protocol clauses the new cases bind to (drift guard) ---"
PROTO_DIR="$SCRIPT_DIR/../protocol"
RP="$PROTO_DIR/routing-protocol.md"
check "§Resolve has a Hive-root locator row for sources/" \
  "$(grep -qF 'Hive-root path' "$RP" && echo 0 || echo 1)"
check "§Extract has the verbatim fall-through clause" \
  "$(grep -qi 'Fall through to the verbatim original' "$RP" && echo 0 || echo 1)"
check "§Match has the restatement step" \
  "$(grep -qi 'Restate the query before scanning' "$RP" && echo 0 || echo 1)"
check "  ...and bounds it against decomposition/HyDE" \
  "$(grep -qi 'restatement, not decomposition' "$RP" && echo 0 || echo 1)"
check "§Answer requires the one-line routing trace" \
  "$(grep -qi 'Close with the routing trace' "$RP" && echo 0 || echo 1)"
check "  ...and ties every citation to the opened list" \
  "$(grep -qF 'must name a locator that appears in `opened:`' "$RP" && echo 0 || echo 1)"
check "§Answer warns the reader on a past-due cited file" \
  "$(grep -qi 'unverified since' "$RP" && echo 0 || echo 1)"
check "§Prefer ranks status questions on [effective:] when present" \
  "$(grep -qF 'most recently *true*' "$RP" && echo 0 || echo 1)"
check "knowledge-schema documents [effective:] as an optional inline annotation" \
  "$(grep -qF '[effective: YYYY-MM-DD]' "$PROTO_DIR/knowledge-schema.md" && echo 0 || echo 1)"
check "fixture paraphrase actually carries [effective:] annotations" \
  "$(grep -qF '[effective: 2026-07-15]' "$LB_NOTES" && echo 0 || echo 1)"

echo ""
echo "--- hive.yml.fixture sanity (no real remote/registry leaked into a fixture) ---"
check "hive.yml.fixture federation is fully opted out (fixture must never touch Confluence/registry)" \
  "$(grep -A2 '^federation:' "$GOLDEN_DIR/hive.yml.fixture" | grep -qF 'register: false' && echo 0 || echo 1)"
check "hive.yml.fixture is NOT literally named hive.yml (must never be cwd-walk discoverable)" \
  "$([[ ! -f "$GOLDEN_DIR/hive.yml" ]] && echo 0 || echo 1)"

echo ""
echo "=============================================="
echo "Part B: LLM-judged behavioral checks (opt-in)"
echo "=============================================="
echo ""

if [[ "${APIARY_GOLDEN_LLM_JUDGE:-0}" != "1" ]]; then
  echo "SKIPPED — set APIARY_GOLDEN_LLM_JUDGE=1 to run. This part makes live model calls,"
  echo "is non-deterministic, and is judged by keyword heuristics, not semantic grading."
  echo "See the file header. To run manually instead: hand each case's Prompt in cases.md"
  echo "to a subagent with cwd=$GOLDEN_DIR and compare against its Pass/Fail criteria by hand."
else
  if ! command -v claude >/dev/null 2>&1; then
    echo "APIARY_GOLDEN_LLM_JUDGE=1 but no 'claude' CLI on PATH — cannot run Part B." >&2
    echo "Falling back to manual-review instructions (see cases.md)." >&2
    FAIL=$((FAIL + 1))
  else
    TRANSCRIPT_DIR="$(mktemp -d)"
    trap 'echo "Transcripts kept at: $TRANSCRIPT_DIR"' EXIT
    echo "Transcripts will be written to: $TRANSCRIPT_DIR"
    echo "(heuristic keyword checks below — read the transcript for anything flagged FAIL)"
    echo ""

    # macOS ships no GNU `timeout`; fall back to gtimeout (coreutils) or run
    # unbounded rather than failing every case with "command not found".
    TIMEOUT_CMD=()
    if command -v timeout >/dev/null 2>&1; then TIMEOUT_CMD=(timeout "${APIARY_GOLDEN_LLM_TIMEOUT:-120}")
    elif command -v gtimeout >/dev/null 2>&1; then TIMEOUT_CMD=(gtimeout "${APIARY_GOLDEN_LLM_TIMEOUT:-120}")
    else echo "note: no timeout/gtimeout on PATH — Part B cases run unbounded"; fi

    judge_case() {
      # judge_case <n> <prompt> <must_contain_regex...>
      local n="$1" prompt="$2"; shift 2
      local out="$TRANSCRIPT_DIR/case-$n.txt"
      echo "--- Case $n ---"
      # APIARY_GOLDEN_CLAUDE_ARGS lets CI pin the run (e.g. "--bare --model sonnet")
      # without changing local behavior. Word-splitting is intended.
      # shellcheck disable=SC2086
      if ( cd "$GOLDEN_DIR" && "${TIMEOUT_CMD[@]+"${TIMEOUT_CMD[@]}"}" claude -p "$prompt" ${APIARY_GOLDEN_CLAUDE_ARGS:-} --allowedTools "Read,Glob,Grep" > "$out" 2>&1 ); then
        local all_ok=0
        for pat in "$@"; do
          if ! grep -qiE "$pat" "$out"; then
            echo "  FAIL: transcript missing expected signal: /$pat/ — see $out"
            all_ok=1
          fi
        done
        if [[ "$all_ok" -eq 0 ]]; then
          echo "  PASS (heuristic): case $n transcript contains all expected signals"
          PASS=$((PASS + 1))
        else
          FAIL=$((FAIL + 1))
        fi
      else
        echo "  FAIL: claude -p invocation errored — see $out"
        FAIL=$((FAIL + 1))
      fi
    }

    judge_case 1 \
      'Using the Reference Library Discovery Protocol (protocol/routing-protocol.md — read it from the installed apiary plugin skill directory), answer: "What subsystems make up the ground segment?" The knowledge tree is ./knowledge here. Cite the file you read.' \
      'overview\.md' 'mission planning|T&C|RF link'

    judge_case 2 \
      'Using the Reference Library Discovery Protocol, answer: "How is the space-to-ground link budget designed?" The knowledge tree is ./knowledge here. Name which authority value (formal/baseline/delivered/working) the row you cited carries.' \
      'formal'

    judge_case 4 \
      'Using the Reference Library Discovery Protocol, answer: "What'"'"'s the pre-2025 command format, per the legacy ground interface catalog?" The knowledge tree is ./knowledge here. State plainly whether the document was actually reachable.' \
      'unresolv|broken|no store root|cannot (reach|resolve|open)|unreachable'

    judge_case 7 \
      'Using the Reference Library Discovery Protocol, answer: "Which document defines the ground station'"'"'s EIRP requirements?" The knowledge tree is ./knowledge here. State explicitly whether you fetched anything.' \
      'PROJ-123|RF Interface Requirements' \
      'no[.]? |not fetch|did not fetch|without fetching|no need to fetch|fetched nothing|nothing external|no external'

    judge_case 8 \
      'Using the Reference Library Discovery Protocol, answer: "What did Demo Corp'"'"'s CDR chart package say about review board comments?" The knowledge tree is ./knowledge here. For this exercise, treat box-skill as NOT installed regardless of what is actually available.' \
      'box-skill' \
      'install'

    judge_case 13 \
      'Using the Reference Library Discovery Protocol, answer: "What'"'"'s the latest link budget document — did anything land after the last catalog update?" The knowledge tree is ./knowledge here. You have no store-search tool installed in this exercise. Show the sufficiency verdict the protocol requires, and what you do about it.' \
      'sufficien' \
      'insufficient|recency' \
      'trawl|as of'

    judge_case 14 \
      'Using the Reference Library Discovery Protocol, answer: "What'"'"'s the thermal vacuum test schedule for the ground segment radios?" The knowledge tree is ./knowledge here. You have no store-search tool installed in this exercise. If you cannot fully answer, say exactly what you did instead and what you recorded.' \
      'ungrounded|no knowledge|not cover|no coverage|does not cover' \
      'gap|\[process\]|inbox contribution'

    # Case 15 asserts the exact value AND the source path. The paraphrase in
    # knowledge/ground-segment/link-budget-notes.md deliberately says "roughly 5 dB", so a
    # transcript-sourced answer and a paraphrase-sourced answer are textually distinguishable.
    judge_case 15 \
      'Using the Reference Library Discovery Protocol, answer: "What exactly did the team commit to for downlink link margin — quote the number from the session." The knowledge tree is ./knowledge here and deposited sources are under ./sources. State which file you quoted from.' \
      '4\.7' \
      'sources/meeting-transcripts|link-budget-sync|transcript'

    judge_case 16 \
      'Using the Reference Library Discovery Protocol, answer: "How is the ground segment structured — what are its subsystems?" The knowledge tree is ./knowledge here. End your answer with the routing trace the protocol requires.' \
      'trace:' \
      'opened:' \
      'overview\.md'
  fi
fi

echo ""
echo "==============================="
echo "Summary: $PASS passed, $FAIL failed"
echo "==============================="
exit $FAIL
