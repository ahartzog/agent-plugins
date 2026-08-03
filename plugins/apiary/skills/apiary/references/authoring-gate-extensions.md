# Authoring a Gate Extension

A **gate extension** adds one Hive-specific check to the pre-push gate. It runs *after* the built-in Sentinel pattern scan has already passed, and it can only ever add a block — never remove one.

Declared via `extensions.gates` in `hive.yml`; frontmatter schema: [`assets/gate-extension.schema.json`](../assets/gate-extension.schema.json); scaffold: [`assets/gate-extension-template.md`](../assets/gate-extension-template.md).

## When you need one

The built-in Sentinel is a fixed regex set — 10 credential patterns and 2 PII patterns (`protocol/sensitive-data-patterns.md`). It is deliberately universal: every Hive gets it, and it detects things that look the same in every domain. A credential looks like a credential everywhere.

Domain risk does not work that way. Consider a Hive covering unclassified engineering work for programs whose *use* of that work is controlled. The following sentence is **synthetic** — it was written as a `block` case in a Hive's gate self-test, and describes no real customer, constellation, or requirement:

> "our customer needs a 12 minute revisit cadence against their GEO belt targets"

No credential. No PII. No classification marking. Every regex in the Sentinel passes it, and that shape of sentence is exactly what must not land. Catching it requires domain judgement — a model reading the diff, or a Hive-specific pattern list of program names.

(Worth noting the general practice: when documenting what a gate should catch, write a synthetic example and label it as such. A real one would have to be redacted from the docs by the very control being described.)

That is what a gate extension is for. Reach for one when your Hive's disclosure risk is **semantic** (needs judgement about meaning) or **domain-specific** (a term list only your Hive knows), and therefore cannot be expressed as a pattern that belongs upstream.

If your check *is* universal — a new credential format, a new PII shape — do not write a gate. Add it to `assets/sentinel-patterns.json` so every Hive benefits (`protocol/sensitive-data-patterns.md` § Adding a pattern).

## What a gate cannot do

These are structural, not conventions — the generator enforces them:

1. **A gate cannot suppress a built-in match.** The pattern scan runs first; on match, the hook reports and exits before any gate is invoked. A gate returning 0 cannot rescue a leaked AWS key. (Design goal 3: extensions are additive only. Design goal 4: Sentinel is non-negotiable.)
2. **A gate cannot disable the Sentinel or another gate.** There is no ordering control and no "skip" declaration.
3. **A gate cannot narrow the file list.** It receives the same candidate files the pattern scan saw.

A gate is therefore always a *tightening*. That is the whole contract, and it is why gates need no upstream approval to add — a Hive can only make its own bar higher.

## The contract

Your command receives:

| | |
|---|---|
| **Arguments** | The candidate files as `"$@"` — changed `_inbox/*.md` and `sources/**/*.md` |
| **`HIVE_ROOT`** | Absolute path to the Hive root (the command's paths resolve relative to it) |
| **`APIARY_SENTINEL_PASSED`** | Always `1` — the built-in scan already passed, so don't redo it |
| **Exit 0** | Allow the push |
| **Non-zero** | Block the push (subject to `on_error`) |
| **stdout / stderr** | Shown to the contributor verbatim — this is your entire UI, so make failures say what to fix |

## Fail closed

`on_error` defaults to `block`, and the generator normalizes any value other than the literal `warn` to `block` — so a typo fails safe. Keep the default. A gate that degrades to "allow" when its dependency is missing is worse than no gate at all, because contributors will have learned to trust it.

Two corollaries worth designing for:

- **Declare `required_tools`.** Checked before invocation, so a missing runtime produces `missing required tool(s): python3` instead of an opaque exit code. Declare everything beyond bash/grep/git.
- **Set `timeout_seconds` on anything that touches the network or a model.** A timeout is treated as a non-zero exit and honors `on_error`. Without it, a hung dependency wedges every contributor's push with no diagnostic.

If a gate genuinely must be bypassable offline, do it *inside* your command via an explicit environment variable (e.g. `MYHIVE_GATE_SKIP_LLM=1`) rather than by setting `on_error: warn`. That keeps the bypass deliberate, greppable, and disclosable in the PR — rather than silently applying to every failure mode including ones you didn't anticipate.

## Budget for push latency

Gates run **sequentially**, in filename order, with no early exit — every gate runs even after one has already blocked, so a contributor sees all failures from a single push rather than one per attempt.

The cost of that choice: worst-case added push latency is the **sum** of every gate's `timeout_seconds`, not the slowest one. Three gates at the worked example's `timeout_seconds: 120` is a six-minute worst case on a bad network. Nothing in the schema bounds the aggregate, so budget it yourself: keep the total of all your gates' timeouts inside what your contributors will tolerate before they reach for `--no-verify`.

Two related caveats:

- `timeout_seconds` is only enforceable if `timeout(1)` is installed. When it is absent the gate runs **unbounded**; the hook says so on stderr rather than pretending the limit applied. Add `timeout` to `required_tools` if a bounded run is load-bearing for you.
- Gates are independent of each other and of the candidate-file list, so they are a reasonable target for concurrent execution if this ever becomes a real pain point. It is deliberately not done today — sequential output is far easier to read, and no Hive yet has enough gates for it to matter.

## Dependencies are yours

Design goal 9 keeps the *Apiary* free of runtime dependencies for contributors: the generated hook needs only bash, grep, and git. Gates are the documented exception, on the same footing as opt-in connectors — if your gate needs `python3` and a model CLI, that is your Hive's dependency to declare in `required_tools`, install, and document in your Hive's `CLAUDE.md`.

This is a real cost. Every contributor to your Hive now needs that toolchain to push. Weigh it before adding a gate, and prefer a gate whose absence degrades loudly (`block` + `required_tools`) over one that silently stops protecting.

## Worked example

`PROTOCOL/extensions/gates/llm-compliance-review.md`:

```markdown
---
layer: PROTOCOL
type: gate-extension
gate: llm-compliance-review
command: python3 scripts/compliance_gate.py
description: >
  LLM review of added lines for program- or customer-specific content. Catches
  disclosure that names no program and matches no regex — e.g. a stated revisit
  cadence against a customer's targets — which the built-in pattern scan cannot see.
last_updated: 2026-07-30
codeowners: [jchen, tgarcia]
on_error: block
timeout_seconds: 120
required_tools: [python3, claude]
---

# LLM compliance review

## What it checks

Every added line in the pushed range, for content that is specific to a program,
customer, or deployment rather than to the general engineering domain this Hive
covers.

## Why the pattern scan is insufficient

The Sentinel is a regex set. It cannot recognise program-specific content that
never names the program. This gate is the layer that reads for meaning.

## Offline behavior

Fails closed. If the model CLI is unavailable the push is blocked. Deliberate
bypass, to be disclosed in the PR:

    MYHIVE_GATE_SKIP_LLM=1 git push
```

Then in `hive.yml`:

```yaml
extensions:
  workflows: null
  gates: PROTOCOL/extensions/gates/
```

That is the whole wiring. The next operate invocation bakes it into the generated hook, and every subsequent regeneration preserves it — which is the point: hardening declared this way survives hook refreshes, whereas a hand-edited `.githooks/pre-push` does not.

## Migrating a hand-rolled hook

If your Hive already hardened `.githooks/pre-push` by hand, operate mode now detects it and prints `SENTINEL_HOOK_PRESERVED_FOREIGN` rather than overwriting it. That keeps your gate working, but the hook is frozen: it will not pick up new Sentinel patterns as upstream adds them.

To migrate:

1. Identify the checks your hook adds beyond the Sentinel pattern scan. Keep the scripts — only the *invocation* moves.
2. Write one gate extension per check (usually one file).
3. Set `extensions.gates` in `hive.yml`.
4. Delete your hand-rolled `.githooks/pre-push`. The next operate invocation regenerates it with your gates baked in and the current pattern set.
5. Verify: make a commit that your gate should block, attempt a push, confirm it blocks and the message is still useful.

Do step 5 before trusting the migration. A gate that no longer fires looks identical to a clean repo.

## Checklist

- [ ] Frontmatter validates against `assets/gate-extension.schema.json`
- [ ] `gate` matches the filename stem
- [ ] `description` states why the built-in pattern scan is insufficient
- [ ] `required_tools` lists everything beyond bash/grep/git
- [ ] `timeout_seconds` set if the gate makes a network or model call
- [ ] `on_error: block` unless the check is genuinely advisory
- [ ] Command lives in-repo and is reviewable next to the declaration
- [ ] Verified it actually blocks something it should block
- [ ] Hive `CLAUDE.md` documents the toolchain contributors now need
