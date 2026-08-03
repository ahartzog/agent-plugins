# Apiary Plugin — Agent Instructions

Auto-loaded whenever you read or edit any file under this directory. Read
[CONTRIBUTING.md](CONTRIBUTING.md) and [DESIGN-GOALS.md](DESIGN-GOALS.md) before making a change here — this file is
the trigger that makes sure you do; it does not restate their content.

## Before opening a PR that touches this plugin

Run the test suites and report the results in the PR body — don't just claim they pass:

```bash
cd plugins/apiary/skills/apiary/tests
bash clone-flow.test.sh
bash apiculturist.test.sh
bash normalizer.test.sh
bash golden-routing.test.sh   # deterministic fixture checks; always run this half
bash sentinel-base.test.sh    # merge-base resolution regression guard (2.16.1)
bash gate-extensions.test.sh  # proves a gate can never suppress a built-in Sentinel match

# sentinel.test.sh needs a generated hook path as its argument:
GEN_HOOK=$(mktemp) && bash ../assets/generate-hook.sh ../assets/sentinel-patterns.json > "$GEN_HOOK" \
  && chmod +x "$GEN_HOOK" && bash sentinel.test.sh "$GEN_HOOK" && rm -f "$GEN_HOOK"
```

If your change touches `protocol/routing-protocol.md`, `protocol/knowledge-schema.md`,
`protocol/document-quality.md`, or `protocol/tool-tiers.md`, also run the behavioral half of the
golden suite and report the transcript summary, not just "cases pass":

```bash
APIARY_GOLDEN_LLM_JUDGE=1 bash golden-routing.test.sh
```

**None of this runs in CI today** (tracked in [BACKLOG.md](BACKLOG.md) § Deterministic Enforcement — "Wire the
Apiary's own `.test.sh` suites into CircleCI"). Until that lands, this file is the only thing
standing between a protocol regression and a merged PR — do not skip it because "CI will catch it."

## Do not confuse test fixtures with real Hive state

`skills/apiary/tests/golden/` is a synthetic fixture Hive for the golden routing/retrieval test
suite — it is not a real Hive and must never be operated on via Create/Operate/Audit/Upgrade mode.
If you find yourself about to run any Apiary mode against a path under `tests/`, stop; that is
always wrong.
