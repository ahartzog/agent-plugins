# Apiary Commercial Decoupling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Strip three org-specific couplings out of the apiary plugin — DoD classification machinery, the internal "Signal" Slack bot, and the Confluence-backed Hive federation/registry — plus the Meridian/claude-clams/GHE org references that thread through the same files, so the plugin stands alone in a commercial environment.

**Architecture:** This is a subtractive change across prose protocol, JSON schemas, one executable bash generator, and four test suites. The removals are ordered so that executable + schema surfaces (which have real tests) land first, then the prose that references them, then the version/changelog gate. A new `tests/decoupling.test.sh` grep guard acts as the failing test for the prose portions, which otherwise have no assertion surface. Sentinel's credential/PII scanning is **preserved in full** — only the classification-banner check leaves.

**Tech Stack:** Bash 3.2 (macOS default), `jq`, `yq`, `ajv`, Python 3 (JSON validation), markdown, JSON Schema draft-07.

---

## Global Constraints

- **Baseline:** branch `apiary-3.0-commercial-decoupling`, cut from `main` at **`a07478b`** (apiary 2.24.0, the Ask-quality pass).
- **⚠ Line numbers in this plan are ADVISORY, not authoritative.** They were derived before 2.24.0 merged, and that PR modified `mode-audit.md`, `mode-operate.md`, `mode-upgrade.md`, `routing-protocol.md`, `knowledge-schema.md`, `external-retrieval-design.md`, `golden-routing.test.sh`, and `golden/cases.md`. **Always re-locate a target by its quoted text, never by line number.** The authoritative worklist is the live `decoupling.test.sh` hit list, re-run at the start of each task. Post-merge footprint: classification 416, federation 179, org-coupling 49, notifications 44.
- **Version:** goes `2.24.0` → **`3.0.0`** in **three** places — `plugins/apiary/.claude-plugin/plugin.json`, `plugins/apiary/.codex-plugin/plugin.json` (added in 2.24.0; carries its own `version` field), and `.claude-plugin/marketplace.json` per `plugins/apiary/CONTRIBUTING.md:125`.
- **CHANGELOG required:** repo-level `CONTRIBUTING.md` makes a `plugins/apiary/CHANGELOG.md` entry mandatory in the same change as any behavior change.
- **Never renumber design goals.** `protocol/design-goals.md` sections are cited by number ("Goal 1", "Goal 2", "Goal 4", "Goal 5", "Goal 9") in ~20 places across `CONTRIBUTING.md`, `references/*-design.md`, `README.md`, and `assets/hive.schema.json`. Goal 3 is rewritten **in place**; the 1–9 numbering does not move.
- **Sentinel is non-negotiable** (`design-goals.md` §4). The credential and PII pattern scan, the override mechanism, the gate-extension layer, and all 18 patterns in `assets/sentinel-patterns.json` survive. Only `_classification_check` and its non-overridable carve-out are removed. The sole edit to `sentinel-patterns.json` is its `$id` string (Task 2 Step 8) — no pattern is added, removed, or altered.
- **Preserve history:** `CHANGELOG.md` and `BACKLOG.md` keep their existing text verbatim, including the removed vocabulary. The guard test excludes them.
- **Total vocabulary purge.** After this change, the strings `CUI`, `ITAR`, `FOUO`, and `UNCLASSIFIED` appear **nowhere** in the plugin outside `CHANGELOG.md` and `BACKLOG.md` — not in README, design goals, protocol files, references, templates, schemas, scripts, tests, or golden fixtures. `assets/sentinel-patterns.json` is already clean (verified: 18 patterns, zero classification markers — the check is hardcoded in `generate-hook.sh`, not data-driven).
- **Do NOT delete the verb "classify."** `references/pre-push-sentinel.md:22` ("Step 2: classify each match"), `pre-push-sentinel.md:74` ("diagnose-and-classify cycle"), and `references/mode-operate.md:326` ("diagnose-and-classify runbook") are the **Sentinel triage runbook** and are unrelated to the classification model. They stay. The guard regex matches `classification`, which does not match `classify` — but a human doing a manual sweep can easily over-delete here. Re-read before cutting any line containing "classif".
- **JSON validity gate:** `python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('**/*.json', recursive=True)]"` must pass before any commit (repo `CLAUDE.md`).
- **Full suite before PR:** every suite named in `plugins/apiary/CLAUDE.md` must run and be reported with real output, not claimed.

## Decisions locked (from the audit conversation)

| Question | Decision |
|---|---|
| Federation scope | **Nuke entirely** — Apiculturist, `siblings`, `federation`, `confluence_registry`, cross-hive suggestions, registry reconciliation |
| Notifications | **Remove entirely** — no generic `notify:` replacement |
| Org coupling | **Bundled in** — Meridian Systems, claude-clams, `ghe.meridian.example`, `meridian/owners` |
| Schema migration | **Cut.** User reaffirmed: no external adopters. `mode-upgrade.md` gets its classification/registry references *removed* (Tasks 3 and 5) rather than gaining a migration stanza. `CONTRIBUTING.md:126` is amended in Task 7 so the rule and the code agree. |
| CUI/ITAR vocabulary | **Total purge** across README, design goals, protocols, references, templates, schemas, and scripts — see Global Constraints and Task 7. |
| Version | Still `3.0.0`. User is indifferent ("won't matter"), but it costs nothing and `CONTRIBUTING.md:126` mandates it for schema changes. |
| Design Goal §3 | Rewritten in place as a generic, mechanism-free sensitivity principle. Numbering preserved. |

---

## File Structure

Paths are relative to `plugins/apiary/`.

**Delete outright**
- `skills/apiary/protocol/apiculturist-workflow.md` — exists only to reconcile against the Confluence registry
- `skills/apiary/tests/apiculturist.test.sh` — tests only the above
- `skills/apiary/tests/golden/hive.yml.fixture` — its own line 2 says it "exists only so the golden-routing.test.sh federation-opt-out check has a hive.yml"

**Create**
- `skills/apiary/tests/decoupling.test.sh` — grep guard; four negative groups (Task 1) plus a `survivors` positive group (Task 7)

**Modify — executable**
- `skills/apiary/assets/generate-hook.sh` — drop `class_from_hive_yml` (~112–137), `_classification_check` (~521–560), the `_covered` carve-out (~486), the `HAS_CLASSIFICATION_FM` frontmatter flag (~278–333), the baked-in ceiling (~155–158), the `_scan_line`/`_classification_check` call site (~588), and the classification paragraph in the emitted help text (~624–626)

**Modify — schemas** (`skills/apiary/assets/`)
- `hive.schema.json` — remove `slack_channel` (from `required` **and** `properties`), `confluence_registry`, `federation`, `siblings`, `classification`; drop `"signal-bot"` from the `auto_merge.mechanism` enum; genericize `$id`
- `knowledge-entry.schema.json`, `inbox-entry.schema.json`, `source-entry.schema.json`, `workflow-extension.schema.json`, `gate-extension.schema.json` — remove the `classification` property; genericize `$id`
- `sentinel-patterns.json` — genericize `$id` only

**Modify — protocol** (`skills/apiary/protocol/`)
- `security-policy.md` — remove §Classification Discipline (60–171, incl. the GHE pre-receive variants) and §Classification Remediation Runbook (215–243). §Prompt Injection Defense, §PII and Credential Rules, §Credential Remediation Runbook, §Attribution Chain, §Rollback, §Repository Protection Model all stay.
- `custodian-workflow.md` — §1.4 Apiculturist dispatch, §2.1 step 5 + the whole direction guard block (325–340), §4.3 partial-fit, §4.1.05/§5 Signal posts (464, 470, 515–531), registry reconcile (253), internal-URL check (354)
- `design-goals.md` — rewrite §3 in place
- `workflows.md` — cross-hive awareness (88), Signal push (122)
- `triage-policy.md` — Signal row (44), "Signal Post?" table column (122)
- `operational-model.md` — Signal notifications row (86), claude-clams reference (166)
- `tool-tiers.md` — Meridian Jira/Confluence rows (21–22), `meridian-claude-clams` marketplace (98)
- `ways-of-working.md` — "Meridian Systems people" people-directory split (26, 62)
- `sensitive-data-patterns.md` — classification-marker section
- `sources-policy.md`, `document-quality.md`, `knowledge-schema.md`, `external-search-agent.md`, `learning-loops.md`, `routing-protocol.md` — incidental references

**Modify — references** (`skills/apiary/references/`)
- `mode-create.md` — Q5 Slack Channel (54), Q5.5 Classification Ceiling (93), Q5.8 Federation (112), Step 3 Signal Config (266), registry `{REGISTRY_URL}` (174), claude-clams registration (224, 332), Meridian example (45)
- `mode-audit.md` — Step 4c Registry Reconciliation (265–315), registry link (267)
- `mode-upgrade.md` — registry backfill (405), classification refs
- `mode-operate.md` — classification refs, Confluence refs
- `pre-push-sentinel.md`, `authoring-gate-extensions.md`, `authoring-workflow-extensions.md`, `merge-disposition-design.md`, `inbox-transport-design.md`, `external-retrieval-*.md`, `push-mode-pr-setup.md` — incidental references

**Modify — assets/templates**
- `hive.yml.template` — classification block (98–104), siblings (37–43), registry, gates example (55), Slack channel
- `readme-template.md` — registry banner (3), `.signal/config.yml` tree entry (49), registry footer (138)
- `agent-definition-template.md`, `child-claude-md-template.md`, `child-skill-template.md`, `inbox-template.md`, `workflow-extension-template.md`

**Modify — top level**
- `SKILL.md` — §Skill Knowledge (96–98) deleted entirely, §Notes federation bullet (106), protocol-file list entries for security-policy and apiculturist
- `README.md` — §Classification Model (184–207), operator steps 1–3 (214–244), order of operations (253)
- `DESIGN-GOALS.md`, `CLAUDE.md`, `CONTRIBUTING.md`
- `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `CHANGELOG.md`, and repo `.claude-plugin/marketplace.json`

**Modify — tests**
- `sentinel.test.sh` — remove classification cases (~383–500); keep every credential/PII case
- `gate-extensions.test.sh` — one classification reference
- `golden-routing.test.sh` — federation-opt-out case
- `golden/cases.md`, `golden/knowledge/ground-segment/document-catalog.md` — fixture text

---

### Task 1: Removal guard test

The prose surfaces have no assertion layer. This builds one first, so every later task has a red-to-green signal.

**Files:**
- Create: `plugins/apiary/skills/apiary/tests/decoupling.test.sh`

**Interfaces:**
- Produces: a suite with four named groups — `classification`, `notifications`, `federation`, `org-coupling` — each exiting non-zero while any forbidden term survives. Later tasks turn one group green each. Accepts optional `$1` = group name to run just one group.

- [ ] **Step 1: Write the failing guard**

```bash
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
```

- [ ] **Step 2: Run it to confirm all four groups fail**

Run: `cd plugins/apiary/skills/apiary/tests && bash decoupling.test.sh`
Expected: FAIL on all four groups, with hit lists. Confirm the counts are in the right ballpark for the 2.24.0 baseline — **classification ~416, notifications ~44, federation ~179, org-coupling ~49**. If a group unexpectedly passes, or a count is off by more than ~20%, the regex is wrong — fix it before proceeding. Save the four hit lists; they are the worklist for Tasks 2–6.

- [ ] **Step 3: Confirm the self-exclusion works**

Run: `cd plugins/apiary/skills/apiary/tests && grep -c 'CUI' decoupling.test.sh`
Expected: ≥1 (the guard names the term) — and the guard must not report itself in Step 2's output. If it does, the `--exclude=decoupling.test.sh` is not taking effect.

- [ ] **Step 4: Commit**

```bash
git add plugins/apiary/skills/apiary/tests/decoupling.test.sh
git commit -m "test(apiary): add decoupling guard for 3.0.0 removals"
```

---

### Task 2: Strip classification from the Sentinel hook generator and schemas

Executable + schema surfaces together, because `class_from_hive_yml` parses the very `hive.yml` block the schema defines. Doing them apart leaves the generator reading a field that no longer validates.

**Files:**
- Modify: `plugins/apiary/skills/apiary/assets/generate-hook.sh`
- Modify: `plugins/apiary/skills/apiary/assets/hive.schema.json`
- Modify: `plugins/apiary/skills/apiary/assets/{knowledge-entry,inbox-entry,source-entry,workflow-extension,gate-extension}.schema.json`
- Modify: `plugins/apiary/skills/apiary/assets/sentinel-patterns.json` (`$id` only)
- Test: `plugins/apiary/skills/apiary/tests/sentinel.test.sh`, `gate-extensions.test.sh`

**Interfaces:**
- Consumes: nothing from Task 1 beyond the guard.
- Produces: a `generate-hook.sh` whose emitted hook reports only credential/PII pattern names. `_covered()` now returns coverable for **every** pattern — the non-overridable carve-out disappears with its only member. `HAS_CLASSIFICATION_FM` and the baked-in `HIVE_CLASS` ceiling are gone from the emitted hook's variable surface.

- [ ] **Step 1: Delete the classification test cases from `sentinel.test.sh`**

Remove the assertions at lines ~383–500 covering `classification.marker`, `classification.unmarked`, `classification.above-ceiling`, and the "override attempt still blocks" case at ~450. Leave every credential/PII case, the merge-base cases, and the frontmatter-override cases intact.

- [ ] **Step 2: Run the suite to confirm it fails**

```bash
cd plugins/apiary/skills/apiary/tests
GEN_HOOK=$(mktemp) && bash ../assets/generate-hook.sh ../assets/sentinel-patterns.json > "$GEN_HOOK" \
  && chmod +x "$GEN_HOOK" && bash sentinel.test.sh "$GEN_HOOK"; echo "rc=$?"; rm -f "$GEN_HOOK"
```

Expected: PASS. Deleting tests does not fail a suite — this step exists to capture the **baseline pass count** before the generator changes. Record the number of assertions. The real failure signal is Step 4.

- [ ] **Step 3: Remove classification from `generate-hook.sh`**

Delete, in this order (bottom-up, so earlier line numbers stay valid):
1. The classification paragraph in the emitted help heredoc (~624–626): the sentence beginning `classification.* findings cannot be overridden:` and its `§ Classification Discipline` pointer. Keep the `sensitive-data-patterns.md` pointer.
2. The `_classification_check "$file" "$abs_line" "$line"` call in the body-line loop (~588).
3. The whole `_classification_check()` function and its comment block (~521–560).
4. In `_covered()` (~486): delete `case "$pat" in classification.*) return 1 ;; esac`. **Keep the rest of `_covered()`** — the override mechanism itself survives.
5. The `HAS_CLASSIFICATION_FM` declaration (~287), its assignment (`[[ "$line" == "classification:"* ]] && HAS_CLASSIFICATION_FM=1`, ~317), and its malformed-frontmatter reset (~333). Keep the surrounding `split_frontmatter` logic.
6. The baked-in ceiling block and its comment (~155–158).
7. The `class_from_hive_yml()` function and comment (~112–137).

- [ ] **Step 4: Regenerate and run — confirm the hook still blocks credentials**

```bash
cd plugins/apiary/skills/apiary/tests
GEN_HOOK=$(mktemp) && bash ../assets/generate-hook.sh ../assets/sentinel-patterns.json > "$GEN_HOOK" \
  && chmod +x "$GEN_HOOK" && bash sentinel.test.sh "$GEN_HOOK"; echo "rc=$?"; rm -f "$GEN_HOOK"
bash gate-extensions.test.sh; echo "rc=$?"
```

Expected: both `rc=0`. If `generate-hook.sh` errors on an unbound variable, a `HAS_CLASSIFICATION_FM` or ceiling reference survives inside the emitted heredoc — grep the generated file, not just the generator.

- [ ] **Step 5: Sanity-check the emitted hook by hand**

```bash
GEN_HOOK=$(mktemp) && bash plugins/apiary/skills/apiary/assets/generate-hook.sh \
  plugins/apiary/skills/apiary/assets/sentinel-patterns.json > "$GEN_HOOK" && chmod +x "$GEN_HOOK"
printf 'CUI\n\nharmless prose\n' > /tmp/cui-probe.md
bash "$GEN_HOOK" scan /tmp/cui-probe.md; echo "cui rc=$? (expect 0 — no longer scanned)"
printf 'aws_secret_access_key = AKIAIOSFODNN7EXAMPLE\n' > /tmp/cred-probe.md
bash "$GEN_HOOK" scan /tmp/cred-probe.md; echo "cred rc=$? (expect 1 — still blocked)"
rm -f "$GEN_HOOK" /tmp/cui-probe.md /tmp/cred-probe.md
```

Expected: `cui rc=0`, `cred rc=1`. This is the load-bearing check that Sentinel survived the surgery.

- [ ] **Step 6: Remove `classification` from the five entry schemas**

In each of `knowledge-entry.schema.json`, `inbox-entry.schema.json`, `source-entry.schema.json`, `workflow-extension.schema.json`, `gate-extension.schema.json`: delete the entire `"classification": { ... }` property object. None of them list it in `required`, so no `required` array edits are needed — verify with `python3 -c "import json;print(json.load(open(F))['required'])"` for each.

- [ ] **Step 7: Remove the five properties from `hive.schema.json`**

- Delete from `"required"`: `"slack_channel"` (leaves `hive_slug`, `description`, `upstream_version`, `persona`, `codeowners`, `remote`, `default_branch`).
- Delete the property objects: `slack_channel`, `confluence_registry`, `federation`, `siblings`, `classification`.
- In `auto_merge.mechanism.enum`, drop `"signal-bot"` → `["pending", "gh-auto-merge-label", "ci-gate"]`.
- **Keep** `purpose` — it is used for discovery and the README, not only cross-hive routing.
- In the `extensions.gates` description, replace the example list `(LLM compliance review, classification scan, domain lint)` with `(LLM compliance review, domain lint, custom sensitivity scan)`. The gate mechanism is the intended home for sensitivity checks post-removal.
- Note: `"additionalProperties": false` means any `hive.yml` still carrying these keys now fails validation. That is intended — see Flagged Items.

- [ ] **Step 8: Genericize the six `$id` values**

Replace `https://ghe.meridian.example/meridian/claude-clams/apiary-sanitized/` with `https://github.com/ahartzog/agent-plugins/apiary/` in `hive.schema.json`, `knowledge-entry.schema.json`, `inbox-entry.schema.json`, `source-entry.schema.json`, `workflow-extension.schema.json`, `sentinel-patterns.json`. Check `gate-extension.schema.json` for an `$id` too.

- [ ] **Step 9: Validate all JSON and re-run both suites**

```bash
cd /Users/alekhartzog/Code/agent-plugins
python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('**/*.json', recursive=True)]" && echo "JSON OK"
cd plugins/apiary/skills/apiary/tests
GEN_HOOK=$(mktemp) && bash ../assets/generate-hook.sh ../assets/sentinel-patterns.json > "$GEN_HOOK" \
  && chmod +x "$GEN_HOOK" && bash sentinel.test.sh "$GEN_HOOK"; echo "rc=$?"; rm -f "$GEN_HOOK"
bash gate-extensions.test.sh; echo "rc=$?"
bash normalizer.test.sh; echo "rc=$?"
```

Expected: `JSON OK` and `rc=0` three times.

- [ ] **Step 10: Commit**

```bash
git add plugins/apiary/skills/apiary/assets plugins/apiary/skills/apiary/tests
git commit -m "feat(apiary)!: remove classification from Sentinel hook and all schemas

BREAKING CHANGE: hive.yml no longer accepts classification, slack_channel,
confluence_registry, federation, or siblings. Sentinel no longer scans for
classification banners; credential and PII scanning is unchanged."
```

---

### Task 3: Delete federation — Apiculturist, registry, cross-hive suggestions

**Files:**
- Delete: `plugins/apiary/skills/apiary/protocol/apiculturist-workflow.md`
- Delete: `plugins/apiary/skills/apiary/tests/apiculturist.test.sh`
- Delete: `plugins/apiary/skills/apiary/tests/golden/hive.yml.fixture`
- Modify: `protocol/custodian-workflow.md`, `protocol/workflows.md`
- Modify: `references/mode-audit.md`, `references/mode-create.md`, `references/mode-upgrade.md`, `references/mode-operate.md`, `references/merge-disposition-design.md`
- Modify: `assets/hive.yml.template`, `assets/readme-template.md`
- Test: `tests/golden-routing.test.sh`, `tests/decoupling.test.sh`

**Interfaces:**
- Consumes: the schema from Task 2 — `siblings`, `federation`, and `confluence_registry` are already gone from `hive.schema.json`, so any surviving prose that tells an operator to set them is now actively wrong.
- Produces: Parliament with no §1.4 Apiculturist dispatch and no cross-hive annotation. `mode-audit` drops from 7 steps + 4 sub-steps to the same minus Step 4c.

- [ ] **Step 1: Delete the three files**

```bash
cd /Users/alekhartzog/Code/agent-plugins/plugins/apiary/skills/apiary
git rm protocol/apiculturist-workflow.md tests/apiculturist.test.sh tests/golden/hive.yml.fixture
```

- [ ] **Step 2: Run the federation guard group to see what remains**

Run: `cd plugins/apiary/skills/apiary/tests && bash decoupling.test.sh federation`
Expected: FAIL, now listing only prose references. Use this hit list as the worklist for Steps 3–6.

- [ ] **Step 3: Excise federation from `custodian-workflow.md`**

- §1.4: delete the Apiculturist dispatch step entirely; renumber nothing — if §1.4 is the last sub-step, the list simply ends at §1.3.
- Line ~253: delete the paragraph explaining why Parliament is the phase that reconciles against the registry.
- §2.1 step 5: delete the entire "Cross-hive fit check" step **and** the nested "Classification direction guard" block (~325–340), including the closing defense-in-depth sentence. Steps 1–4 of §2.1 remain.
- §4.3 (~470): delete the "Partial-fit" verdict row/paragraph. The other verdicts stay.
- §5 (~515): delete the "Cross-hive suggestions" bullet.
- §4.1.05 (~464): the Clean MERGE definition cites "(Signal post to `slack_channel` + one-`git revert` rollback)" as the post-hoc human gate. Rewrite to: `the human gate is post-hoc (batch PR is visible in the repo's PR history and reverts cleanly with a single `git revert`)`. **This is a substantive protocol edit, not a deletion** — the auto-merge rationale must still stand on its own.
- Line ~354: the `[link]` URL validation references `ghe.meridian.example`, `confluence.meridian.example`, `jira.meridian.example`. Rewrite to `an internal system (any host on the organization's private network)`.

- [ ] **Step 4: Excise federation from `workflows.md`**

Delete the "Cross-hive awareness (non-blocking)" paragraph at ~88 in full.

- [ ] **Step 5: Excise from the mode files**

- `mode-audit.md`: delete Step 4c Registry Reconciliation Check (~265–315). Renumber nothing — 4, 4b, 5, 6, 7 remain, and 4c simply vanishes. Update any Step-count claim in `mode-audit.md`'s intro or in Step 7's report template.
- `mode-create.md`: delete Q5.8 Federation (~112–131); delete the `{REGISTRY_URL}` placeholder definition (~174) and every emission of it into `hive.yml`, `README.md`, and `CLAUDE.md`.
- `mode-upgrade.md`: delete the `confluence_registry` backfill (~405) and any siblings/federation migration.
- `mode-operate.md` and `merge-disposition-design.md`: remove incidental references per the guard hit list.

- [ ] **Step 6: Excise from templates**

- `hive.yml.template`: delete the siblings block (~37–43) and its explanatory comment about the per-sibling classification requirement, plus the registry line.
- `readme-template.md`: delete the registry banner (line 3) and the registry footer (~138).

- [ ] **Step 7: Fix the golden suite**

`golden-routing.test.sh` has a federation-opt-out case that depended on the deleted `hive.yml.fixture`. Delete that case. Run the deterministic half:

```bash
cd plugins/apiary/skills/apiary/tests && bash golden-routing.test.sh; echo "rc=$?"
```

Expected: `rc=0`. If it errors on a missing `hive.yml.fixture`, another case reads the fixture — either restore a minimal fixture with only the fields the surviving cases need, or update those cases.

- [ ] **Step 8: Confirm the federation group goes green**

Run: `cd plugins/apiary/skills/apiary/tests && bash decoupling.test.sh federation`
Expected: `PASS [federation]`

- [ ] **Step 9: Commit**

```bash
git add -A plugins/apiary
git commit -m "feat(apiary)!: remove Hive federation, registry reconciliation, and the Apiculturist

BREAKING CHANGE: Hives no longer track siblings or reconcile against a central
registry. Parliament no longer emits cross-hive suggestions. The auto-merge
post-hoc gate now rests on PR visibility and git revert alone."
```

---

### Task 4: Remove Signal and all notification plumbing

**Files:**
- Modify: `protocol/custodian-workflow.md`, `protocol/triage-policy.md`, `protocol/operational-model.md`, `protocol/workflows.md`
- Modify: `references/mode-create.md`, `references/push-mode-pr-setup.md`
- Modify: `assets/readme-template.md`, `assets/hive.yml.template`
- Modify: `README.md`
- Test: `tests/decoupling.test.sh`

**Interfaces:**
- Consumes: `slack_channel` and `signal-bot` are already gone from `hive.schema.json` (Task 2), and the §4.1.05 auto-merge rationale was already rewritten (Task 3 Step 3). This task removes the remaining prose only.
- Produces: no notification surface anywhere in the plugin. Parliament's outputs are the batch PR and `_custodian/reports/`.

- [ ] **Step 1: Run the notifications guard group for the worklist**

Run: `cd plugins/apiary/skills/apiary/tests && bash decoupling.test.sh notifications`
Expected: FAIL with the remaining hit list.

- [ ] **Step 2: Remove the Signal posting lines**

- `custodian-workflow.md` §5 (~516, 521, 526, 531): delete the four "Signal bot posts to slack_channel (from hive.yml)" lines. Each sits under a PR-type heading — leave the headings and their other bullets.
- `triage-policy.md`: delete the "→ Signal bot posts to slack_channel" clause at ~44; delete the "Signal Post?" column from the table at ~122, including the header cell, the separator cell, and every row's cell.
- `operational-model.md`: delete the "Signal notifications | **Working** | ..." table row at ~86.
- `workflows.md` (~122): rewrite step 7 to drop the Slack option — `7. Optional: write to \`_custodian/reports/brief-YYYY-WNN.md\`.`

- [ ] **Step 3: Remove the config-generation path**

- `mode-create.md`: delete Q5 Slack Channel (~54–58) and Step 3 Generate Signal Config (~264–271) in full. **Renumber the remaining steps** — Step 4 Validate Rendered Output becomes Step 3, and so on. Then grep for stale cross-references: `grep -rn "Step [4-9]" plugins/apiary/skills/apiary/references/mode-create.md plugins/apiary/README.md plugins/apiary/skills/apiary/SKILL.md` and fix each. Note `SKILL.md:94` cites "Create mode Step 4 runs these checks automatically" and `README.md:260` cites "Create mode Step 8".
- `hive.yml.template`: delete the `slack_channel` line and comment.
- `readme-template.md`: delete the `.signal/config.yml` line from the directory tree (~49).

- [ ] **Step 4: Remove the operator setup step**

`README.md`: delete §3 "Set up Signal (Slack notifications)" (~235–243) including the `#sw-signal` and Signal v3 doc links. Renumber §4 "Set codeowners correctly" → §3. Update §"Order of operations, end to end" (~253) to match.

`push-mode-pr-setup.md` (~189): the GHE auto-merge note ends "consider a lightweight webhook if that becomes painful." Keep the sentence — it is a generic suggestion, not a Signal reference — but confirm the guard regex does not flag it. If it does, the `Signal` word is elsewhere on that line; re-read before editing.

- [ ] **Step 5: Confirm the notifications group goes green**

Run: `cd plugins/apiary/skills/apiary/tests && bash decoupling.test.sh notifications`
Expected: `PASS [notifications]`

- [ ] **Step 6: Commit**

```bash
git add -A plugins/apiary
git commit -m "feat(apiary)!: remove Signal bot and all Slack notification plumbing

BREAKING CHANGE: hive.yml no longer accepts slack_channel and Create mode no
longer generates .signal/config.yml. Parliament reports via the batch PR and
_custodian/reports/ only."
```

---

### Task 5: Remove classification prose and rewrite Design Goal 3

The largest prose surface, and the one with the subtle trap: Design Goal 3 must be **rewritten**, not deleted.

**Files:**
- Modify: `protocol/security-policy.md`, `protocol/design-goals.md`, `protocol/sensitive-data-patterns.md`, `protocol/sources-policy.md`, `protocol/document-quality.md`, `protocol/knowledge-schema.md`, `protocol/tool-tiers.md`, `protocol/external-search-agent.md`
- Modify: `references/mode-create.md`, `references/mode-audit.md`, `references/mode-upgrade.md`, `references/mode-operate.md`, `references/pre-push-sentinel.md`, `references/authoring-gate-extensions.md`, `references/external-retrieval-caching-design.md`
- Modify: `assets/hive.yml.template`, `assets/agent-definition-template.md`, `assets/child-claude-md-template.md`, `assets/readme-template.md`, `assets/inbox-template.md`, `assets/child-skill-template.md`, `assets/workflow-extension-template.md`
- Modify: `README.md`, `DESIGN-GOALS.md`, `CONTRIBUTING.md`
- Modify: `tests/golden/cases.md`, `tests/golden/knowledge/ground-segment/document-catalog.md`

**Interfaces:**
- Consumes: the schemas and hook from Task 2.
- Produces: Design Goal 3 retitled but still occupying slot 3, so every `Goal 1/2/4/5/9` citation elsewhere stays correct.

- [ ] **Step 1: Rewrite Design Goal 3 in place**

In `protocol/design-goals.md`, replace lines 50–56 (heading through the `---`) with:

```markdown
## 3. Sensitivity Is Hive-Local

The Apiary core carries no sensitivity taxonomy. A Hive that must enforce one — PHI, PCI, trade-secret, or a bespoke public/internal/confidential ladder — declares it as a **gate extension** (`references/authoring-gate-extensions.md`), which runs in the generated pre-push hook after the built-in Sentinel scan and cannot suppress it.

This keeps the core free of any one organization's marking regime while leaving the enforcement point exactly where a marking check belongs. Sentinel's credential and PII scanning is unconditional and unrelated: it applies to every Hive regardless of sensitivity posture (`protocol/security-policy.md`).

---
```

- [ ] **Step 2: Verify no goal citation broke**

```bash
cd /Users/alekhartzog/Code/agent-plugins/plugins/apiary
grep -rnE "Goal [0-9]|design.goals?.md §[0-9]" --include="*.md" . | grep -v BACKLOG
```

Expected: every hit cites Goal 1, 2, 4, 5, or 9 — no hit cites Goal 3. If one does, rewrite that citation to point at the new §3 meaning or at `security-policy.md`.

- [ ] **Step 3: Excise the three classification sections from `security-policy.md`**

- Delete §Classification Discipline and every subsection through §GHE Pre-Receive Hook Reference — heading line 60 up to but **not including** `## Credential Remediation Runbook` at 172. That removes: Hive Configuration, Two Operating Modes, Required Markings, Session Agent Behavior, GHE Pre-Receive Hook Reference.
- Delete §Classification Remediation Runbook — heading at 215 up to but **not including** `## Attribution Chain` at 244.
- One line inside the deleted GHE section is worth preserving: the force-push rule at ~167 (`Force push is blocked on {DEFAULT_BRANCH} ... "Master Branch Safety" branch ruleset with no bypass actors. [learned: 2026-04-16]`). Move it into §Repository Protection Model (275) before deleting the section.
- Update §Scope of This Policy (333) if it enumerates the removed sections.

- [ ] **Step 4: Update the gate-extension authoring doc**

`references/authoring-gate-extensions.md` cites a classification scan as an example gate. Keep the example but reframe it as the **recommended home** for sensitivity checks now that core carries none — this is the migration path for anyone who wanted the old behavior. Reword so the word `classification` does not survive; use "sensitivity marking scan."

- [ ] **Step 5: Rewrite the README classification sections**

- Delete §Classification Model (184–207) entirely.
- Delete operator step §1 "Decide the classification ceiling first — it determines which org the repo lives in" (214–226). Renumber the remaining operator steps.
- Update §"Order of operations, end to end" (253) to match the new step count, after Task 4 already renumbered it once.

- [ ] **Step 6: Two substantive rewrites — these are NOT deletions**

Both of these are places where classification was load-bearing for a *different* decision. Deleting the text silently changes behavior; each needs a replacement rule.

**(a) `references/external-retrieval-caching-design.md` §Classification (198).** The section head is "Classification — the constraint that gates the default," and the rule reads: `Default enabled: true only for a Hive whose ceiling is UNCLASSIFIED with marking_required: false. Any Hive above that defaults to disabled, opt-in via hive.yml.cache.enabled: true`. Remove the classification condition and the default has no gate at all. Retitle to `## Exposure — the constraint that gates the default` and replace the rule with:

```markdown
- **Default `enabled: false` for every Hive.** Caching is opt-in via
  `hive.yml.cache.enabled: true` — a deliberate act by codeowners who accept
  unscanned fetched content on local disk.
```

The three exposure facts above it (cache is unscanned by Sentinel, unmarked, outlives the session) are true independent of any sensitivity model — keep all three, deleting only the words "carries no classification marking" from the first bullet, which becomes `The cache root is not covered by the Hive's protection model.` Also fix line 73: `Puts fetched external content inside the Hive's classification boundary` → `inside the Hive's protection boundary`.

**(b) `references/mode-create.md` Q5.7 Purpose example (108).** `purpose` survives this change, but its worked example is `"Releasable, unclassified program knowledge for non-US-accessible teams. CUI/ITAR/SECRET+ content does NOT belong here — it lives in vault-hive (restricted-org)."` Replace with a commercial-neutral example that still demonstrates the "what does *not* belong here" half of the field:

```markdown
Example: "Platform runtime and deployment knowledge for the services team.
Customer contract terms and pricing do NOT belong here — those live with Legal."
```

- [ ] **Step 7: Sweep remaining files from the guard hit list**

Run `bash decoupling.test.sh classification` and work the list. Notable non-obvious ones:
- `hive.yml.template` (98–104): delete the whole commented classification block; also line 28's "Neither switch is a security control — classification is …" and line 55's gates example.
- `mode-create.md`: delete Q5.5 Classification Ceiling (~93–104), then renumber if the Q-numbering is now gappy (it already uses Q5.25/Q5.3/Q5.35, so gaps are idiomatic here — leave the remaining numbers alone).
- `sensitive-data-patterns.md`: remove the classification-marker patterns section; **keep** every credential and PII pattern.
- `tests/golden/knowledge/ground-segment/document-catalog.md:28` and `tests/golden/cases.md:185`: the fixture filename `2.1_2.4 - CDR Ground Segment Design (CUI).pptx` is testing the empty-`covers` trawling case, not classification. Rename it to `... Design (Internal).pptx` in **both** files so the golden case still matches.
- `README.md:171`: the Security row of the Protocol Contract table ends `; classification findings non-overridable` — delete that clause, keep the rest of the row.
- `README.md:199`: `Unmarked classified content is quarantined by Parliament Sentinel.` — delete the line.
- `mode-operate.md:164`: the Identity parse-list enumerates `slack_channel`, `confluence_registry` → `{REGISTRY_URL}`, `siblings` → `{SIBLINGS}` (each `{slug, purpose, repo, classification}`). Remove those three from the list; keep `purpose` → `{HIVE_PURPOSE}` and everything else.
- `mode-upgrade.md:133`: the sentence describing what a Hive "gains the push modes, the `classification` block, and the `federation` block" — remove the two dead blocks from the list.
- `mode-create.md:306`: the registry row-markup step cites `apiculturist-workflow.md` §3 and its "highlighted Max Classification cell" — this whole step dies with Task 3; verify it is already gone.
- `DESIGN-GOALS.md` and `CONTRIBUTING.md`: check whether either enumerates Goal 3 by title.

- [ ] **Step 8: Confirm the classification group goes green and golden still passes**

```bash
cd plugins/apiary/skills/apiary/tests
bash decoupling.test.sh classification
bash golden-routing.test.sh; echo "rc=$?"
```

Expected: `PASS [classification]` and `rc=0`.

- [ ] **Step 9: Commit**

```bash
git add -A plugins/apiary
git commit -m "feat(apiary)!: remove classification model; Design Goal 3 becomes Hive-local sensitivity

BREAKING CHANGE: the CUI/FOUO/UNCLASSIFIED ceiling model, marking discipline,
and classification remediation runbook are removed. Hives needing a sensitivity
taxonomy declare one as a gate extension."
```

---

### Task 6: Genericize the Meridian / claude-clams / GHE org coupling

**Files:**
- Modify: `SKILL.md`, `README.md`, `DESIGN-GOALS.md`
- Modify: `protocol/tool-tiers.md`, `protocol/ways-of-working.md`, `protocol/operational-model.md`
- Modify: `references/mode-create.md`, `references/authoring-workflow-extensions.md`
- Modify: `tests/golden/knowledge/people/profiles/jane-demo.md`, `sam-demo.md`

**Interfaces:**
- Consumes: nothing — independent of Tasks 2–5, but sequenced last among the removals because it touches the same README and mode-create regions those tasks already rewrote.
- Produces: no organization-specific host, marketplace, or repo name anywhere outside CHANGELOG/BACKLOG.

- [ ] **Step 1: Delete the SKILL.md "Skill Knowledge" section**

Remove `SKILL.md` lines 96–98 in full — heading and paragraph. It hardcodes one org's marketplace into the router and has no generic replacement. While in `SKILL.md`, also fix the §Protocol Files list: remove the `apiculturist-workflow.md` bullet (deleted in Task 3), and rewrite the `security-policy.md` bullet's description from "CUI defense-in-depth, PII, injection defense" to "PII, credential, and injection defense."

- [ ] **Step 2: Rewrite the §Notes federation bullet**

`SKILL.md:106` is the "Hives are federated" bullet. Delete it entirely — Task 3 removed the mechanism it describes.

- [ ] **Step 3: Genericize `tool-tiers.md`**

- Rows 21–22: replace `Meridian Systems Jira (jira.meridian.example)` → `the organization's Jira instance`; same shape for Confluence.
- Line 98: replace `claude plugin install <skill>@meridian-claude-clams` with `claude plugin install <skill>@<marketplace>`, and rewrite the trailing sentence "If the skill lives in a different marketplace than `meridian-claude-clams`…" to reference `<marketplace>` generically.

- [ ] **Step 4: Genericize the remaining prose**

- `ways-of-working.md` (26, 62): `Meridian Systems people` → `organization-internal people` in the people-directory layout.
- `operational-model.md` (166): `a PR to the Apiary skill in claude-clams` → `a PR to the Apiary plugin repository`.
- `authoring-workflow-extensions.md` (22, 161): `claude-clams PR` → `upstream Apiary PR`.
- `mode-create.md` (45): the Widget/Meridian example — rewrite to a neutral two-org example. (224, 332): `register the child skill in claude-clams` → `register the child skill in your plugin marketplace`.
- `DESIGN-GOALS.md` (90): `PR review on claude-clams` → `PR review on the Apiary plugin repository`.
- `tests/golden/.../jane-demo.md` and `sam-demo.md`: `not a real Meridian Systems employee` → `not a real employee`.

- [ ] **Step 5: Rewrite the README operator section**

`README.md` §2 "Create the GHE repo via `meridian/owners`" (~227–234) describes a centrally-provisioned repo flow through an `owners` repo and a `repo-provisioner` CI pipeline. Replace the whole subsection with a generic two-sentence instruction: create an empty repo on the git host, note its clone URL, set it as `hive.yml.remote`. Then sweep remaining `GHE` uses — most are legitimately about GitHub Enterprise behavior (branch rulesets, pre-receive hooks, auto-merge); rewrite those to "GitHub Enterprise" spelled out on first use, or "the git host" where the behavior is not GHE-specific. `GHE` is **not** in the guard regex, so this is judgment, not a hard gate.

- [ ] **Step 6: Confirm the org-coupling group goes green**

Run: `cd plugins/apiary/skills/apiary/tests && bash decoupling.test.sh`
Expected: all four groups `PASS`.

- [ ] **Step 7: Commit**

```bash
git add -A plugins/apiary
git commit -m "refactor(apiary): genericize org-specific references (Meridian, claude-clams, GHE)"
```

---

### Task 7: CUI/ITAR vocabulary sweep and survivor verification

Tasks 2–6 remove the vocabulary as a side effect of removing the machinery. This task proves it, catches residue in the places the earlier hit lists don't reach (filenames, fixture data, comments inside scripts), and adds a **positive** assertion so the Sentinel triage runbook can't be gutted by an over-eager future sweep.

**Files:**
- Modify: `plugins/apiary/skills/apiary/tests/decoupling.test.sh`
- Modify: whatever the sweep surfaces

**Interfaces:**
- Consumes: all four guard groups green from Tasks 2–6.
- Produces: `decoupling.test.sh` gains a `survivors` group asserting that legitimate content still exists. Total group count goes 4 → 5.

- [ ] **Step 1: Case-insensitive sweep including filenames**

```bash
cd /Users/alekhartzog/Code/agent-plugins/plugins/apiary
echo "--- file CONTENTS ---"
grep -rniE '\b(cui|itar|fouo|unclassified)\b' . \
  --exclude-dir=.git --exclude=CHANGELOG.md --exclude=BACKLOG.md --exclude=decoupling.test.sh
echo "--- file NAMES ---"
find . -path ./.git -prune -o -iname '*cui*' -print -o -iname '*itar*' -print -o -iname '*fouo*' -print
```

Expected: both empty. Word boundaries matter — `\bcui\b` will not fire on "circuit" or "cuisine", which is exactly the false-positive class `generate-hook.sh:523` warns about. If a hit appears inside a golden fixture, fix the fixture **and** any golden case that asserts against its text; the two must move together.

- [ ] **Step 2: Confirm the survivors are intact**

```bash
cd /Users/alekhartzog/Code/agent-plugins/plugins/apiary/skills/apiary
grep -n "classify each match" references/pre-push-sentinel.md
grep -n "diagnose-and-classify" references/pre-push-sentinel.md references/mode-operate.md
grep -c "" assets/sentinel-patterns.json && python3 -c "
import json; print('patterns:', len(json.load(open('assets/sentinel-patterns.json'))['patterns']))"
```

Expected: the first two greps return hits (the Sentinel triage runbook survived), and the pattern count is still **18**. A pattern count below 18 means credential/PII coverage was collaterally damaged — stop and restore.

- [ ] **Step 3: Add the `survivors` group to the guard**

Append a positive-assertion group so a future sweep cannot silently delete the triage runbook or thin the pattern file. Add this function and call after the existing `check_group` calls:

```bash
check_present() {
  local label="$1" file="$2" pattern="$3"
  if grep -qE "$pattern" "$ROOT/$file" 2>/dev/null; then
    printf 'PASS [survivors] %s\n' "$label"
  else
    printf 'FAIL [survivors] %s — expected %s in %s\n' "$label" "$pattern" "$file" >&2
    FAILED=1
  fi
}

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
```

Also update the usage comment on line 2 to list the fifth group.

- [ ] **Step 4: Run the full guard**

Run: `cd plugins/apiary/skills/apiary/tests && bash decoupling.test.sh`
Expected: five `PASS` lines — `classification`, `notifications`, `federation`, `org-coupling`, plus four `survivors` assertions.

- [ ] **Step 5: Commit**

```bash
git add -A plugins/apiary
git commit -m "test(apiary): assert CUI/ITAR purge and verify Sentinel survivors"
```

---

### Task 8: Full suite, version bump, CHANGELOG

**Files:**
- Modify: `plugins/apiary/.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `plugins/apiary/CHANGELOG.md`
- Modify: `plugins/apiary/CLAUDE.md` (suite list), `plugins/apiary/CONTRIBUTING.md`

**Interfaces:**
- Consumes: all prior tasks.
- Produces: a releasable `3.0.0`.

- [ ] **Step 1: Run every suite and capture real output**

```bash
cd /Users/alekhartzog/Code/agent-plugins/plugins/apiary/skills/apiary/tests
bash clone-flow.test.sh;        echo "clone-flow rc=$?"
bash normalizer.test.sh;        echo "normalizer rc=$?"
bash golden-routing.test.sh;    echo "golden rc=$?"
bash sentinel-base.test.sh;     echo "sentinel-base rc=$?"
bash gate-extensions.test.sh;   echo "gate-ext rc=$?"
bash decoupling.test.sh;        echo "decoupling rc=$?"
GEN_HOOK=$(mktemp) && bash ../assets/generate-hook.sh ../assets/sentinel-patterns.json > "$GEN_HOOK" \
  && chmod +x "$GEN_HOOK" && bash sentinel.test.sh "$GEN_HOOK"; echo "sentinel rc=$?"; rm -f "$GEN_HOOK"
```

Note `apiculturist.test.sh` is intentionally absent — deleted in Task 3.
Expected: `rc=0` for all seven. Paste this output into the PR body verbatim.

- [ ] **Step 2: Update the suite list in `plugins/apiary/CLAUDE.md`**

Remove the `bash apiculturist.test.sh` line; add `bash decoupling.test.sh  # guards the 3.0.0 org-decoupling removals`.

- [ ] **Step 3: Run repo-level validation**

```bash
cd /Users/alekhartzog/Code/agent-plugins
python3 -c "import json,glob; [json.load(open(f)) for f in glob.glob('**/*.json', recursive=True)]" && echo "JSON OK"
python3 .circleci/validate_plugins.py; echo "rc=$?"
```

Expected: `JSON OK`, `rc=0`.

- [ ] **Step 4: Bump all three version surfaces**

```bash
cd /Users/alekhartzog/Code/agent-plugins
grep -n '"version"' plugins/apiary/.claude-plugin/plugin.json plugins/apiary/.codex-plugin/plugin.json
```

Set both to `"3.0.0"` (each reads `2.24.0` at the 2.24.0 baseline). `.codex-plugin/plugin.json` was added in the 2.24.0 merge and is easy to miss — the two manifests must not drift. Then check `.claude-plugin/marketplace.json`: the apiary entry carries no `version` field today, so confirm no change is needed and say so in the PR rather than silently skipping it.

- [ ] **Step 5: Write the CHANGELOG entry**

Prepend to `plugins/apiary/CHANGELOG.md`, matching the file's existing heading style:

```markdown
## 3.0.0 — Commercial decoupling

Removes three organization-specific couplings. Breaking: existing `hive.yml`
files must have the removed keys deleted before they will validate.

### Removed
- **Classification model.** The `UNCLASSIFIED`/`FOUO`/`CUI` ceiling, `hive.yml.classification`,
  the `classification` frontmatter field on all five entry schemas, Sentinel's
  classification-banner check, the GHE pre-receive variants, and the classification
  remediation runbook. Hives needing a sensitivity taxonomy now declare one as a
  gate extension — see `references/authoring-gate-extensions.md`.
- **Signal / Slack notifications.** `hive.yml.slack_channel`, `.signal/config.yml`,
  Create mode's Signal step, and the `signal-bot` auto-merge mechanism.
- **Federation and the Hive Mind Registry.** `hive.yml.siblings`, `federation`,
  `confluence_registry`, the Apiculturist subagent and its Parliament §1.4 dispatch,
  cross-hive suggestions, the classification direction guard, and Audit Step 4c.
- Organization-specific references (Meridian Systems, claude-clams, `ghe.meridian.example`,
  the `meridian/owners` provisioning flow).
- The strings `CUI`, `ITAR`, `FOUO`, and `UNCLASSIFIED` no longer appear anywhere in the
  plugin outside this changelog and `BACKLOG.md`.

### Changed
- **Design Goal 3** is now "Sensitivity Is Hive-Local." Goal numbering is unchanged;
  every `Goal N` citation elsewhere remains valid.
- Parliament's auto-merge post-hoc human gate now rests on PR visibility plus
  `git revert`, no longer on a Slack post.
- Sentinel's override mechanism no longer has a non-overridable pattern class,
  because `classification.*` was its only member. Credential and PII scanning
  is otherwise unchanged.
- **External-retrieval caching now defaults to disabled for every Hive.** The default
  was previously gated on a Hive's classification ceiling; with no ceiling to read,
  the conservative default applies universally and caching is opt-in via
  `hive.yml.cache.enabled: true`.
- `CONTRIBUTING.md` migration rule now covers removed fields, not just added ones,
  and allows a stated skip when no Hive runs the prior schema.

### Added
- `tests/decoupling.test.sh` — guards all four removals against regression.
```

- [ ] **Step 6: Amend `CONTRIBUTING.md:126` so the rule matches reality**

The line currently reads: `- **Schema changes = major version bump.** New required fields in `hive.yml` are breaking. Add a migration to `mode-upgrade.md`.` This change removes fields with no migration, by decision. Rewrite to:

```markdown
- **Schema changes = major version bump.** Added required fields and removed fields
  are both breaking. Add a migration to `mode-upgrade.md` when any Hive is known to
  be running the prior schema; state in the PR when none is and the migration is
  therefore skipped.
```

- [ ] **Step 7: Verify against CONTRIBUTING's gates**

Re-read `plugins/apiary/CONTRIBUTING.md` §Design Goals Compliance (131) and answer each of the Goal 1/2/4/5/9 questions for this change in the PR body. Two things must be stated explicitly, not assumed:

1. **Second Brain cross-check: checked, no change needed.** Second Brain has no classification-ceiling, Signal, or registry coupling; its `classif*` hits are decay classification, triage reclassification, and `doc_type` classification, all unrelated to the removed model.
2. **Migration skipped deliberately** under the amended CONTRIBUTING:126 — no Hive is running the 2.x schema.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "chore(apiary): release 3.0.0 — commercial decoupling"
```

---

## Flagged Items

1. **`additionalProperties: false` makes this hard-breaking, with no migration.** Any existing `hive.yml` carrying `slack_channel` (which was **required**), `classification`, `siblings`, `federation`, or `confluence_registry` fails validation immediately on 3.0, with no deprecation window and no upgrade path. This is a deliberate decision on the stated grounds that no Hive runs the 2.x schema. **If that turns out to be wrong, the recovery is manual**: delete those five keys from `hive.yml`, delete `.signal/`, strip `classification:` frontmatter from `knowledge/**`, `_inbox/**`, and `sources/**`, then set `upstream_version: 3.0.0`. Task 8 Step 6 amends CONTRIBUTING so the rule permits this; Task 8 Step 7 requires it be said out loud in the PR.

2. **Sentinel's non-overridable class becomes empty.** `_covered()` currently hard-refuses overrides for `classification.*` only. Removing it means every pattern is overridable via frontmatter `sentinel_override`. Credential patterns were always overridable, so this is not a regression — but the *mechanism* must survive the edit. Task 2 Step 3 item 4 calls this out specifically.

3. **The §4.1.05 auto-merge rationale is load-bearing prose.** Parliament auto-merges with no pre-merge human review because a Signal post gives a post-hoc gate. Deleting the post without rewriting the justification would leave an unjustified auto-merge path. Task 3 Step 3 rewrites it to rest on PR visibility + `git revert`. If that feels thin, the alternative is flipping `auto_merge.tribunal_passed` to default false — a bigger protocol decision, out of scope here, worth a BACKLOG entry.

4. **Caching's default flips from conditional to off.** `external-retrieval-caching-design.md` gated `cache.enabled: true` on "ceiling is UNCLASSIFIED with `marking_required: false`." Remove classification and that condition evaluates to nothing — leaving the default either universally on (wrong: the cache is unscanned by Sentinel, unmarked, and outlives the session) or universally off. Task 5 Step 6(a) picks **off, opt-in**. Flagging because it is a behavior change hiding inside a vocabulary purge, and because the three exposure facts that justify it were always independent of classification.

5. **Two false-friend classes in the sweep.** (a) The verb `classify` in the Sentinel triage runbook is legitimate and must survive — Task 7 Step 3 adds a positive assertion so a future sweep can't quietly delete it. (b) `CUI` is a substring of ordinary English ("circuit", "cuisine"); `generate-hook.sh:523` documents this exact false-positive class as the reason its own check is banner-shaped. Every sweep in this plan uses `\b` word boundaries.

6. **`purpose` survives.** It was partly justified by cross-hive routing, but it also drives discovery and README generation. Keeping it — its worked example is rewritten in Task 5 Step 6(b), since the current one is built entirely on CUI/ITAR.

7. **BACKLOG cleanup not included.** `BACKLOG.md:299-303` (the five structural couplings) is now three-fifths done, and `BACKLOG.md:290` describes local mode as needing "no Parliament/Signal/classification." Both should be updated after this lands, but the guard excludes BACKLOG deliberately, so it will not nag. Worth a follow-up commit.

8. **`sensitivity ladder` is not built.** You said you like the public/internal/confidential idea but don't want it wired now. Design Goal 3's rewrite points at gate extensions as the interim home, which keeps the door open without shipping a taxonomy.
