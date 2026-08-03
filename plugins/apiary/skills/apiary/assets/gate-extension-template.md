---
layer: PROTOCOL
type: gate-extension
gate: GATE_NAME
command: COMMAND_TO_RUN
description: >
  ONE_LINE_WHAT_THIS_CHECKS_AND_WHY_THE_BUILTIN_PATTERN_SCAN_CANNOT_SEE_IT
last_updated: YYYY-MM-DD
codeowners: [GITHUB_USERNAME]
on_error: block
timeout_seconds: 0
required_tools: [TOOL_NAME]
---

# GATE_NAME

## What it checks

WHAT_CONTENT_THIS_INSPECTS_AND_OVER_WHAT_SCOPE

## Why the pattern scan is insufficient

WHY_THIS_CANNOT_BE_A_SENTINEL_REGEX. If it *could* be a regex that every Hive
would want, add it to `assets/sentinel-patterns.json` upstream instead of
writing a gate — see `protocol/sensitive-data-patterns.md` § Adding a pattern.

## Behavior on failure

WHAT_THE_CONTRIBUTOR_SEES_AND_WHAT_THEY_SHOULD_DO. Remember the gate's
stdout/stderr is its entire UI — a block that doesn't say what to fix will get
worked around rather than fixed.

## Offline / degraded behavior

Fails closed (`on_error: block`). DESCRIBE_ANY_DELIBERATE_BYPASS, e.g.:

    MYHIVE_GATE_SKIP_X=1 git push

Prefer an explicit in-command bypass over `on_error: warn`, so the escape hatch
is deliberate and greppable rather than applying to every failure mode.

---

Authoring guide: `references/authoring-gate-extensions.md`
Frontmatter schema: `assets/gate-extension.schema.json`
