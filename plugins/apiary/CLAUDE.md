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

**CI status:** the deterministic suites run on every PR via `.github/workflows/apiary-tests.yml`
(make it a required check in branch protection if it isn't yet), and the behavioral half runs
weekly / on demand / when a maintainer labels a same-repo PR `golden-behavioral`
(`.github/workflows/apiary-golden-behavioral.yml`; needs the `ANTHROPIC_API_KEY` repo secret).
Still run the suites locally before pushing — CI confirms, it does not replace the discipline —
and for routing-file changes paste the Part B transcript summary into the PR body either way.

## Do not confuse test fixtures with real Hive state

`skills/apiary/tests/golden/` is a synthetic fixture Hive for the golden routing/retrieval test
suite — it is not a real Hive and must never be operated on via Create/Operate/Audit/Upgrade mode.
If you find yourself about to run any Apiary mode against a path under `tests/`, stop; that is
always wrong.
